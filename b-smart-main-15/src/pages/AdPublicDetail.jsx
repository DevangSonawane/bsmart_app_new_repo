import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import api from '../lib/api';
import {
  ArrowLeft, Heart, MessageCircle, Share2, Bookmark,
  Globe, Phone, Mail, MessageSquare, ExternalLink,
  MapPin, Tag, Play, Volume2, VolumeX, BadgeCheck,
  ShoppingBag, Eye, ChevronRight, ChevronLeft, X, Film, MoreHorizontal,
} from 'lucide-react';

const BASE_URL = 'https://api.bebsmart.in';

const fmt = (n = 0) => {
  if (!n) return '0';
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const toAbsoluteUploadUrl = (value) => {
  if (!value) return null;
  if (/^http:\/\/api\.bebsmart\.in/i.test(String(value))) {
    return String(value).replace(/^http:\/\//i, 'https://');
  }
  if (String(value).startsWith('http')) return value;
  const normalized = String(value).replace(/^\/+/, '');
  if (normalized.startsWith('uploads/')) return `${BASE_URL}/${normalized}`;
  return `${BASE_URL}/uploads/${normalized}`;
};

const getPreviewMedia = (item) => {
  const media = item?.media?.[0];
  const isVideo = media?.media_type === 'video' || media?.type === 'video' || item?.type === 'reel';
  const thumb = isVideo
    ? toAbsoluteUploadUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url)
    : toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);
  const src = toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);

  return { media, isVideo, thumb, src };
};

// ─── Gallery helpers ──────────────────────────────────────────────────────────
const getMediaType = (fname = '', url = '') => {
  const src = fname || url;
  const ext = src.split('.').pop().split('?')[0].toLowerCase();
  if (['mp4', 'webm', 'mov', 'm4v'].includes(ext)) return 'video';
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'svg'].includes(ext)) return 'image';
  if (url.includes('.mp4') || url.includes('.webm')) return 'video';
  return 'image';
};

// ─── Lightbox ─────────────────────────────────────────────────────────────────
const GalleryLightbox = ({ items, startIdx, onClose }) => {
  const [idx, setIdx] = useState(startIdx);
  const item  = items[idx];
  const url   = item?.link || item?.fileUrl || item?.url || '';
  const fname = item?.filename || item?.filname || item?.fileName || '';
  const mtype = getMediaType(fname, url);
  const total = items.length;

  useEffect(() => {
    const handler = (e) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowLeft')  setIdx(i => (i - 1 + total) % total);
      if (e.key === 'ArrowRight') setIdx(i => (i + 1) % total);
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [total, onClose]);

  return (
    <div
      className="fixed inset-0 z-[200] bg-black/92 backdrop-blur-md flex items-center justify-center p-4"
      onClick={onClose}
    >
      {/* Close */}
      <button
        onClick={onClose}
        className="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors z-10"
      >
        <X className="w-5 h-5" />
      </button>

      {/* Counter */}
      <div className="absolute top-4 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-black/50 text-white text-xs font-bold">
        {idx + 1} / {total}
      </div>

      {/* Prev */}
      {total > 1 && (
        <button
          onClick={e => { e.stopPropagation(); setIdx(i => (i - 1 + total) % total); }}
          className="absolute left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors z-10"
        >
          <ChevronLeft className="w-5 h-5" />
        </button>
      )}

      {/* Media */}
      <div
        className="max-w-3xl w-full max-h-[85vh] flex items-center justify-center"
        onClick={e => e.stopPropagation()}
      >
        {mtype === 'video' ? (
          <video
            src={url}
            controls
            autoPlay
            className="max-w-full max-h-[85vh] rounded-2xl shadow-2xl"
          />
        ) : (
          <img
            src={url}
            alt={fname}
            className="max-w-full max-h-[85vh] rounded-2xl shadow-2xl object-contain"
          />
        )}
      </div>

      {/* Next */}
      {total > 1 && (
        <button
          onClick={e => { e.stopPropagation(); setIdx(i => (i + 1) % total); }}
          className="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors z-10"
        >
          <ChevronRight className="w-5 h-5" />
        </button>
      )}

      {/* Filename */}
      {fname && (
        <p className="absolute bottom-16 left-1/2 -translate-x-1/2 text-xs text-white/50 font-mono">{fname}</p>
      )}

      {/* Thumbnail strip */}
      {total > 1 && (
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5 px-3 py-2 bg-black/50 rounded-2xl">
          {items.map((it, i) => {
            const turl  = it.link || it.fileUrl || it.url || '';
            const tfn   = it.filename || it.filname || it.fileName || '';
            const ttype = getMediaType(tfn, turl);
            return (
              <button
                key={i}
                onClick={e => { e.stopPropagation(); setIdx(i); }}
                className={`w-10 h-10 rounded-lg overflow-hidden border-2 transition-all ${i === idx ? 'border-white scale-110' : 'border-transparent opacity-60 hover:opacity-90'}`}
              >
                {ttype === 'video' ? (
                  <div className="w-full h-full bg-gray-700 flex items-center justify-center">
                    <Play className="w-3 h-3 text-white fill-white" />
                  </div>
                ) : (
                  <img src={turl} alt="" className="w-full h-full object-cover" />
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ─── Public Gallery Section ───────────────────────────────────────────────────
// Matches the "More from [Vendor]" reference style: horizontal card grid,
// clicking opens lightbox for images or plays video inline.
const AdGallerySection = ({ items }) => {
  const [lightboxIdx, setLightboxIdx] = useState(null);
  if (!items || items.length === 0) return null;

  return (
    <>
      <div className="mt-8">
        {/* Header — mirrors the "More from Expert Shoes / See all" reference */}
        <div className="flex items-center gap-2 mb-3">
          <Film size={15} className="text-pink-500" />
          <p className="text-sm font-bold text-gray-900 dark:text-white">Gallery</p>
        </div>

        {/* Grid — portrait cards matching the reference screenshot */}
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-2.5">
          {items.map((item, idx) => {
            const url   = toAbsoluteUploadUrl(item.link || item.fileUrl || item.url || item.fileName || item.filename || item.filname || '');
            const fname = item.filename || item.filname || item.fileName || '';
            const mtype = getMediaType(fname, url);

            return (
              <button
                key={item._id || item.id || idx}
                onClick={() => setLightboxIdx(idx)}
                className="group relative rounded-xl overflow-hidden bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-pink-400 hover:shadow-md transition-all focus:outline-none"
                style={{ aspectRatio: '9/16' }}
              >
                {mtype === 'video' ? (
                  <>
                    <video
                      src={url}
                      className="w-full h-full object-cover"
                      muted
                      preload="metadata"
                    />
                    {/* Play icon overlay */}
                    <div className="absolute inset-0 bg-black/25 group-hover:bg-black/35 transition-colors flex items-center justify-center">
                      <div className="w-8 h-8 rounded-full bg-white/80 flex items-center justify-center group-hover:scale-110 transition-transform shadow">
                        <Play className="w-3.5 h-3.5 text-gray-800 fill-gray-800 ml-0.5" />
                      </div>
                    </div>
                  </>
                ) : (
                  <>
                    <img
                      src={url}
                      alt={fname}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      onError={e => { e.currentTarget.style.display = 'none'; }}
                    />
                    {/* Hover overlay */}
                    <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                      <div className="opacity-0 group-hover:opacity-100 transition-opacity w-8 h-8 rounded-full bg-white/80 flex items-center justify-center shadow">
                        <Eye className="w-3.5 h-3.5 text-gray-700" />
                      </div>
                    </div>
                  </>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Lightbox */}
      {lightboxIdx !== null && (
        <GalleryLightbox
          items={items}
          startIdx={lightboxIdx}
          onClose={() => setLightboxIdx(null)}
        />
      )}
    </>
  );
};

// ─── HLS Video Player ─────────────────────────────────────────────────────────
const VideoPlayer = ({ src, thumb, muted, onToggleMute }) => {
  const videoRef = useRef(null);
  const hlsRef   = useRef(null);
  const pendingPlayRef = useRef(false);
  const [playing, setPlaying] = useState(false);
  const [ready, setReady]     = useState(false);
  const [loadError, setLoadError] = useState(false);

  const attemptPlay = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    const playPromise = video.play();
    if (playPromise?.catch) {
      playPromise
        .then(() => {
          pendingPlayRef.current = false;
          setPlaying(true);
        })
        .catch(() => {
          pendingPlayRef.current = true;
        });
      return;
    }
    pendingPlayRef.current = false;
    setPlaying(true);
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !src) return;
    setReady(false);
    setPlaying(false);
    setLoadError(false);
    pendingPlayRef.current = false;

    const markReady = () => {
      setReady(true);
      if (pendingPlayRef.current) attemptPlay();
    };

    const setupHls = () => {
      if (hlsRef.current) { hlsRef.current.destroy(); hlsRef.current = null; }
      if (window.Hls?.isSupported()) {
        const hls = new window.Hls({ enableWorker: false });
        hlsRef.current = hls;
        hls.loadSource(src);
        hls.attachMedia(video);
        hls.on(window.Hls.Events.MANIFEST_PARSED, markReady);
        hls.on(window.Hls.Events.ERROR, (_, data) => {
          if (data?.fatal) setLoadError(true);
        });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = src;
        markReady();
      } else {
        setLoadError(true);
      }
    };

    if (src.includes('.m3u8')) {
      if (window.Hls) { setupHls(); }
      else {
        const s = document.createElement('script');
        s.src = 'https://cdn.jsdelivr.net/npm/hls.js@1.4.12/dist/hls.min.js';
        s.onload = setupHls;
        document.head.appendChild(s);
      }
    } else {
      video.src = src;
      markReady();
    }

    return () => { if (hlsRef.current) { hlsRef.current.destroy(); hlsRef.current = null; } };
  }, [attemptPlay, src]);

  useEffect(() => { if (videoRef.current) videoRef.current.muted = muted; }, [muted]);

  const toggle = () => {
    const v = videoRef.current;
    if (!v) return;
    if (v.paused) {
      if (!ready) {
        pendingPlayRef.current = true;
        return;
      }
      attemptPlay();
    }
    else { v.pause(); setPlaying(false); }
  };

  return (
    <div className="relative w-full bg-black rounded-2xl overflow-hidden cursor-pointer" style={{ aspectRatio: '9/16' }} onClick={toggle}>
      {thumb && !playing && (
        <img src={thumb} alt="thumbnail" className="absolute inset-0 w-full h-full object-cover" />
      )}
      <video
        ref={videoRef}
        muted={muted}
        playsInline
        loop
        preload="metadata"
        className="w-full h-full object-cover"
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
        onCanPlay={() => {
          setReady(true);
          if (pendingPlayRef.current) attemptPlay();
        }}
        onError={() => setLoadError(true)}
      />
      {loadError && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/55 px-6 text-center">
          <p className="text-xs font-semibold text-white/85">Video could not be loaded.</p>
        </div>
      )}
      {!playing && !loadError && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/20">
          <div className="w-16 h-16 rounded-full bg-black/60 backdrop-blur-sm flex items-center justify-center hover:scale-110 transition-transform shadow-2xl">
            <Play size={26} className="text-white fill-white ml-1" />
          </div>
        </div>
      )}
      <button
        onClick={(e) => {
          e.stopPropagation();
          onToggleMute();
        }}
        className="absolute bottom-3 right-3 w-8 h-8 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-colors z-10"
      >
        {muted ? <VolumeX size={14} /> : <Volume2 size={14} />}
      </button>
    </div>
  );
};

// ─── CTA Button ───────────────────────────────────────────────────────────────
const CtaButton = ({ cta, adId }) => {
  if (!cta?.type) return null;
  const trackClick = () => { try { api.post(`/ads/${adId}/click`); } catch {} };

  const map = {
    view_site:    { label: 'Visit Website', icon: <Globe size={15} />,        color: 'from-orange-500 to-pink-600',    href: cta.url?.trim() || cta.deep_link?.trim() },
    call_now:     { label: 'Call Now',      icon: <Phone size={15} />,        color: 'from-green-500 to-emerald-600',  href: `tel:${cta.phone_number}` },
    install_app:  { label: 'Install App',   icon: <ExternalLink size={15} />, color: 'from-blue-500 to-indigo-600',   href: cta.url?.trim() },
    book_now:     { label: 'Book Now',      icon: <ExternalLink size={15} />, color: 'from-purple-500 to-pink-600',   href: cta.url?.trim() },
    contact_info: { label: 'Contact Us',    icon: <Mail size={15} />,         color: 'from-teal-500 to-cyan-600',     href: `mailto:${cta.email}` },
    learn_more:   { label: 'Learn More',    icon: <ExternalLink size={15} />, color: 'from-gray-700 to-gray-900',     href: cta.url?.trim() },
  };

  const cfg = map[cta.type] || map.learn_more;
  if (!cfg.href) return null;

  return (
    <a
      href={cfg.href}
      target={cta.type !== 'call_now' ? '_blank' : '_self'}
      rel="noopener noreferrer"
      onClick={trackClick}
      className={`w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl bg-gradient-to-r ${cfg.color} text-white font-bold text-sm shadow-lg hover:opacity-90 active:scale-[0.98] transition-all`}
    >
      {cfg.icon}{cfg.label}
    </a>
  );
};

// ─── Mini Ad Card for vendor ads grid ────────────────────────────────────────
const MiniAdCard = ({ ad, onClick }) => {
  const media = ad.media?.[0];
  const thumb = media?.media_type === 'video'
    ? toAbsoluteUploadUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url)
    : toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);
  const isVid = media?.media_type === 'video';

  return (
    <button
      onClick={() => onClick(ad._id)}
      className="relative overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 group cursor-pointer"
      style={{ aspectRatio: '9/16' }}
    >
      {thumb ? (
        <img src={thumb} alt={ad.ad_title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
      ) : (
        <div className="w-full h-full bg-gradient-to-br from-orange-100 to-pink-100 dark:from-orange-900/30 dark:to-pink-900/30 flex items-center justify-center">
          <ShoppingBag size={20} className="text-orange-300" />
        </div>
      )}
      {isVid && (
        <div className="absolute top-1.5 right-1.5 w-5 h-5 rounded-full bg-black/60 flex items-center justify-center">
          <Play size={8} className="text-white fill-white ml-0.5" />
        </div>
      )}
      <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-1">
        <span className="flex items-center gap-1 text-white text-xs font-bold">
          <Heart size={11} className="fill-white" />{fmt(ad.likes_count || 0)}
        </span>
        <span className="flex items-center gap-1 text-white text-xs font-bold">
          <Eye size={11} />{fmt(ad.views_count || 0)}
        </span>
      </div>
    </button>
  );
};

// ─── Main Component ───────────────────────────────────────────────────────────
const MobileSuggestedAdsSection = ({ ads, loading, onOpenAd }) => {
  if (!loading && ads.length === 0) return null;

  return (
    <div className="md:hidden mt-8 -mx-4 px-4 py-5 border-y border-gray-100 dark:border-gray-800 bg-white/50 dark:bg-white/[0.02]">
      <div className="flex items-center justify-between mb-3">
        <div>
          <p className="text-lg font-bold text-gray-900 dark:text-white">Suggested ads</p>
          <p className="text-xs text-gray-400">More ads you may want to explore</p>
        </div>
        <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-gray-400">Mobile</span>
      </div>

      {loading ? (
        <div className="flex gap-3 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {[...Array(3)].map((_, idx) => (
            <div key={idx} className="w-[42vw] max-w-[190px] min-w-[150px] rounded-[28px] bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '9/16' }} />
          ))}
        </div>
      ) : (
        <div className="flex gap-3 overflow-x-auto snap-x snap-mandatory pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {ads.map((item) => {
            const media = item.media?.[0];
            const thumb = media?.media_type === 'video'
              ? toAbsoluteUploadUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url)
              : toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);

            return (
              <button
                key={item._id}
                onClick={() => onOpenAd(item._id)}
                className="group snap-start w-[42vw] max-w-[190px] min-w-[150px] text-left"
              >
                <div className="relative overflow-hidden rounded-[28px] bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-sm" style={{ aspectRatio: '9/16' }}>
                  {thumb ? (
                    <img src={thumb} alt={item.ad_title || item.caption || 'Suggested ad'} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                  ) : (
                    <div className="w-full h-full bg-gradient-to-br from-orange-100 to-pink-100 dark:from-orange-900/30 dark:to-pink-900/30 flex items-center justify-center">
                      <ShoppingBag size={22} className="text-orange-300" />
                    </div>
                  )}

                  {media?.media_type === 'video' && (
                    <div className="absolute top-2.5 right-2.5 w-7 h-7 rounded-full bg-black/60 flex items-center justify-center backdrop-blur-sm">
                      <Play size={10} className="text-white fill-white ml-0.5" />
                    </div>
                  )}

                  <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black/90 via-black/45 to-transparent">
                    <p className="text-[11px] font-bold text-white line-clamp-2">{item.ad_title || item.caption || 'Suggested ad'}</p>
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};

const MobileSuggestedReelsSection = ({ reels, loading, onOpenReel }) => {
  if (!loading && reels.length === 0) return null;

  return (
    <div className="md:hidden mt-8 -mx-4 px-4 py-5 border-y border-gray-100 dark:border-gray-800 bg-[#0d0d0f]">
      <div className="flex items-center justify-between mb-3">
        <p className="text-lg font-bold text-white">Suggested reels</p>
        <button type="button" className="p-1.5 rounded-full text-white/80">
          <MoreHorizontal size={18} />
        </button>
      </div>

      {loading ? (
        <div className="flex gap-3 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {[...Array(3)].map((_, idx) => (
            <div key={idx} className="w-[42vw] max-w-[190px] min-w-[150px] rounded-[24px] bg-white/5 animate-pulse" style={{ aspectRatio: '9/16' }} />
          ))}
        </div>
      ) : (
        <div className="flex gap-3 overflow-x-auto snap-x snap-mandatory pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {reels.map((reel) => {
            const { isVideo, thumb, src } = getPreviewMedia(reel);
            const title = reel.caption || reel.title || reel.user_id?.username || 'Suggested reel';

            return (
              <button
                key={reel._id}
                onClick={() => onOpenReel(reel._id)}
                className="group snap-start w-[42vw] max-w-[190px] min-w-[150px] text-left"
              >
                <div className="relative overflow-hidden rounded-[24px] bg-black border border-white/10 shadow-[0_12px_30px_rgba(0,0,0,0.35)]" style={{ aspectRatio: '9/16' }}>
                  {isVideo && src ? (
                    <>
                      {thumb && <img src={thumb} alt="" className="absolute inset-0 w-full h-full object-cover group-hover:opacity-0 transition-opacity duration-300" />}
                      <video
                        src={src}
                        muted
                        loop
                        playsInline
                        preload="metadata"
                        className="w-full h-full object-cover"
                      />
                    </>
                  ) : thumb ? (
                    <img src={thumb} alt={title} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full bg-gradient-to-br from-gray-800 to-gray-950" />
                  )}

                  <div className="absolute inset-x-0 top-0 p-2.5 flex items-center justify-end">
                    <div className="w-7 h-7 rounded-full bg-black/45 backdrop-blur-sm flex items-center justify-center text-white">
                      <MoreHorizontal size={14} />
                    </div>
                  </div>

                  <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black via-black/45 to-transparent">
                    <div className="flex items-center gap-2 mb-2">
                      {reel.user_id?.avatar_url ? (
                        <img src={toAbsoluteUploadUrl(reel.user_id.avatar_url)} alt={reel.user_id?.username || 'User'} className="w-7 h-7 rounded-full object-cover border border-white/20" />
                      ) : (
                        <div className="w-7 h-7 rounded-full bg-white/15 border border-white/15" />
                      )}
                      <span className="text-[11px] font-semibold text-white truncate">
                        {reel.user_id?.username || reel.user_id?.full_name || 'reel'}
                      </span>
                    </div>
                    <p className="text-[11px] leading-4 text-white/95 line-clamp-2">{title}</p>
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default function AdPublicDetail() {
  const { adId }   = useParams();
  const navigate   = useNavigate();
  const { userObject } = useSelector(s => s.auth);

  const [ad, setAd]           = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState('');
  const [isMuted, setIsMuted] = useState(true);

  const [liked, setLiked]             = useState(false);
  const [likesCount, setLikesCount]   = useState(0);
  const [likeLoading, setLikeLoading] = useState(false);

  const [vendorAds, setVendorAds]               = useState([]);
  const [vendorAdsLoading, setVendorAdsLoading] = useState(false);
  const [suggestedReels, setSuggestedReels] = useState([]);
  const [suggestedReelsLoading, setSuggestedReelsLoading] = useState(false);

  useEffect(() => {
    if (!adId) return;
    setLoading(true);
    api.get(`/ads/${adId}`)
      .then(res => {
        const data = res.data?.ad || res.data;
        setAd(data);
        setLiked(data.is_liked_by_me || false);
        setLikesCount(data.likes_count || 0);
      })
      .catch(() => setError('Could not load ad.'))
      .finally(() => setLoading(false));
  }, [adId]);

  useEffect(() => {
    if (!ad) return;
    const uid = ad.user_id?._id || ad.vendor_id?._id;
    if (!uid) return;
    setVendorAdsLoading(true);
    api.get(`/ads/user/${uid}`)
      .then(res => {
        const list = Array.isArray(res.data) ? res.data : res.data?.ads || res.data?.data || [];
        setVendorAds(list.filter(a => a._id !== adId).slice(0, 6));
      })
      .catch(() => {})
      .finally(() => setVendorAdsLoading(false));
  }, [ad, adId]);

  useEffect(() => {
    setSuggestedReelsLoading(true);
    api.get('/suggestions/reels', { params: { limit: 10 } })
      .then((res) => {
        const list = Array.isArray(res.data)
          ? res.data
          : Array.isArray(res.data?.data) ? res.data.data
          : Array.isArray(res.data?.reels) ? res.data.reels
          : [];
        setSuggestedReels(list.filter((item) => item?._id && item._id !== adId).slice(0, 10));
      })
      .catch(() => setSuggestedReels([]))
      .finally(() => setSuggestedReelsLoading(false));
  }, [adId]);

  const toggleLike = async () => {
    if (!userObject || likeLoading) return;
    const wasLiked = liked;
    setLikeLoading(true);
    setLiked(!wasLiked);
    setLikesCount(c => wasLiked ? Math.max(0, c - 1) : c + 1);
    try {
      await api.post(`/ads/${adId}/${wasLiked ? 'unlike' : 'like'}`);
    } catch {
      setLiked(wasLiked);
      setLikesCount(c => wasLiked ? c + 1 : Math.max(0, c - 1));
    } finally { setLikeLoading(false); }
  };

  if (loading) return (
    <div className="min-h-screen bg-gray-50 dark:bg-black flex items-center justify-center">
      <div className="w-10 h-10 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );

  if (error || !ad) return (
    <div className="min-h-screen bg-gray-50 dark:bg-black flex flex-col items-center justify-center gap-4 p-6">
      <p className="text-gray-500 dark:text-gray-400">{error || 'Ad not found.'}</p>
      <button onClick={() => navigate(-1)} className="text-pink-600 font-bold text-sm hover:underline">← Go Back</button>
    </div>
  );

  const media        = ad.media?.[0];
  const videoSrc     = toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);
  const thumbSrc     = toAbsoluteUploadUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url);
  const isVideo      = media?.media_type === 'video';
  const imageSrc     = !isVideo ? toAbsoluteUploadUrl(media?.fileUrl || media?.fileName) : null;
  const vendorName   = ad.vendor_id?.business_name || ad.user_id?.full_name || 'Vendor';
  const vendorAvatar = ad.user_id?.avatar_url || '';
  const vendorId     = ad.user_id?._id || ad.vendor_id?._id;
  const isVerified   = ad.vendor_id?.validated === true;

  // Gallery items — API uses 'gallery' field (fallback: 'detail')
  const galleryItems = Array.isArray(ad.gallery) && ad.gallery.length > 0
    ? ad.gallery
    : Array.isArray(ad.detail) && ad.detail.length > 0
      ? ad.detail
      : [];

  const highlights = [
    ad.category      && { label: 'Category', value: ad.category,                icon: <Tag size={13} className="text-violet-500" />,     bg: 'bg-violet-50 dark:bg-violet-950/30 border-violet-100 dark:border-violet-900/20' },
    ad.location      && { label: 'Location', value: ad.location,                icon: <MapPin size={13} className="text-rose-500" />,     bg: 'bg-rose-50 dark:bg-rose-950/30 border-rose-100 dark:border-rose-900/20' },
    ad.ad_type       && { label: 'Type',     value: ad.ad_type.replace('_',' '),icon: <Play size={13} className="text-amber-500" />,      bg: 'bg-amber-50 dark:bg-amber-950/30 border-amber-100 dark:border-amber-900/20' },
    ad.target_language?.length > 0 && { label: 'Language', value: ad.target_language.slice(0,2).join(', '), icon: <Globe size={13} className="text-blue-500" />, bg: 'bg-blue-50 dark:bg-blue-950/30 border-blue-100 dark:border-blue-900/20' },
    ad.status        && { label: 'Status',   value: ad.status,                  icon: <BadgeCheck size={13} className="text-emerald-500" />, bg: 'bg-emerald-50 dark:bg-emerald-950/30 border-emerald-100 dark:border-emerald-900/20' },
  ].filter(Boolean);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-[#0a0a0a] font-sans">

      {/* ── Top Bar ── */}
      <div className="sticky top-0 z-40 bg-white/95 dark:bg-black/95 backdrop-blur-md border-b border-gray-100 dark:border-gray-800 flex items-center gap-3 px-4 py-3">
        <button onClick={() => navigate(-1)} className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors flex-shrink-0">
          <ArrowLeft size={20} className="text-gray-800 dark:text-white" />
        </button>
        <div className="flex items-center gap-2 flex-1 min-w-0">
          {vendorAvatar
            ? <img src={vendorAvatar} className="w-7 h-7 rounded-full object-cover flex-shrink-0" alt={vendorName} />
            : <div className="w-7 h-7 rounded-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">{vendorName[0]}</div>
          }
          <span className="text-sm font-bold text-gray-900 dark:text-white truncate">{vendorName}</span>
          {isVerified && (
            <span className="w-4 h-4 rounded-full bg-[#0095f6] flex items-center justify-center flex-shrink-0">
              <BadgeCheck size={9} className="text-white" strokeWidth={3} />
            </span>
          )}
        </div>
        <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full border flex-shrink-0 ${
          ad.status === 'active'
            ? 'bg-emerald-50 text-emerald-600 border-emerald-200 dark:bg-emerald-900/20 dark:text-emerald-400 dark:border-emerald-900/30'
            : 'bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-700'
        }`}>{ad.status}</span>
      </div>

      {/* ── Main layout ── */}
      <div className="max-w-5xl mx-auto px-4 py-5 pb-16">
        <div className="flex flex-col md:flex-row gap-5">

          {/* ── LEFT: Video / Image ── */}
          <div className="flex-shrink-0 w-full md:w-[280px] lg:w-[300px]">
            {isVideo ? (
              <VideoPlayer src={videoSrc} thumb={thumbSrc} muted={isMuted} onToggleMute={() => setIsMuted(m => !m)} />
            ) : imageSrc ? (
              <div className="rounded-2xl overflow-hidden bg-black shadow-xl" style={{ aspectRatio: '9/16' }}>
                <img src={imageSrc} alt={ad.ad_title} className="w-full h-full object-cover" />
              </div>
            ) : (
              <div className="rounded-2xl overflow-hidden bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600 flex items-center justify-center shadow-xl" style={{ aspectRatio: '9/16' }}>
                <p className="text-white font-bold text-xl text-center px-6">{vendorName}</p>
              </div>
            )}

            {/* Engagement */}
            <div className="flex items-center gap-4 mt-3 px-1">
              <button
                onClick={toggleLike}
                className="flex items-center gap-1.5 text-sm font-bold text-gray-600 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition-colors"
              >
                <Heart size={18} className={liked ? 'text-red-500 fill-red-500' : ''} />
                {fmt(likesCount)}
              </button>
              <div className="flex items-center gap-1.5 text-sm font-bold text-gray-500 dark:text-gray-400">
                <MessageCircle size={18} />{fmt(ad.comments_count || 0)}
              </div>
              <div className="flex items-center gap-1.5 text-sm font-bold text-gray-500 dark:text-gray-400">
                <Eye size={18} />{fmt(ad.views_count || 0)}
              </div>
            </div>
          </div>

          {/* ── RIGHT: Info ── */}
          <div className="flex-1 min-w-0 space-y-4">

            {/* Vendor row */}
            <div className="flex items-center gap-3">
              <Link to={`/vendor/${vendorId}/public`} className="flex items-center gap-2.5 flex-1 min-w-0">
                <div className="w-10 h-10 rounded-xl overflow-hidden bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white font-bold text-sm flex-shrink-0 shadow-md">
                  {vendorAvatar ? <img src={vendorAvatar} alt={vendorName} className="w-full h-full object-cover" /> : vendorName[0]}
                </div>
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="font-bold text-gray-900 dark:text-white text-sm truncate">{vendorName}</span>
                    {isVerified && (
                      <span className="w-4 h-4 rounded-full bg-[#0095f6] flex items-center justify-center flex-shrink-0">
                        <BadgeCheck size={9} className="text-white" strokeWidth={3} />
                      </span>
                    )}
                  </div>
                  <span className="text-xs text-gray-400">@{ad.user_id?.username || 'vendor'}</span>
                </div>
              </Link>
              <Link
                to={`/vendor/${vendorId}/public`}
                className="flex-shrink-0 text-xs font-bold text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-gray-700 px-3 py-1.5 rounded-full hover:border-gray-300 dark:hover:border-gray-600 transition-colors"
              >
                View Profile
              </Link>
            </div>

            {/* Ad title */}
            <h1 className="text-xl font-extrabold text-gray-900 dark:text-white leading-tight">
              {ad.ad_title}
            </h1>

            {/* Ad description */}
            {ad.ad_description && (
              <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{ad.ad_description}</p>
            )}

            {/* CTA */}
            {ad.cta?.type && <CtaButton cta={ad.cta} adId={adId} />}

            {/* Contact buttons */}
            {(ad.cta?.whatsapp_number || ad.cta?.phone_number || ad.cta?.email) && (
              <div className="flex gap-2 flex-wrap">
                {ad.cta?.whatsapp_number && (
                  <a href={`https://wa.me/${ad.cta.whatsapp_number.replace(/\D/g,'')}`} target="_blank" rel="noopener noreferrer"
                    className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-400 text-xs font-bold hover:bg-green-100 transition-colors">
                    <MessageSquare size={12} /> WhatsApp
                  </a>
                )}
                {ad.cta?.phone_number && (
                  <a href={`tel:${ad.cta.phone_number}`}
                    className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 text-blue-700 dark:text-blue-400 text-xs font-bold hover:bg-blue-100 transition-colors">
                    <Phone size={12} /> Call
                  </a>
                )}
                {ad.cta?.email && (
                  <a href={`mailto:${ad.cta.email}`}
                    className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 text-purple-700 dark:text-purple-400 text-xs font-bold hover:bg-purple-100 transition-colors">
                    <Mail size={12} /> Email
                  </a>
                )}
              </div>
            )}

            {/* Highlights */}
            {highlights.length > 0 && (
              <div>
                <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-2">Top Highlights</p>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {highlights.map((h, i) => (
                    <div key={i} className={`border rounded-xl p-3 flex flex-col gap-1.5 ${h.bg}`}>
                      {h.icon}
                      <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest leading-none">{h.label}</div>
                      <div className="text-xs font-bold text-gray-800 dark:text-gray-100 capitalize leading-tight">{h.value}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Caption */}
            {ad.caption && (
              <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-4">
                <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-2">Caption</p>
                <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-line">
                  {ad.caption.split('\n').slice(0, 4).join('\n')}
                </p>
              </div>
            )}

            {/* Hashtags */}
            {ad.hashtags?.length > 0 && (
              <div className="flex flex-wrap gap-1.5">
                {ad.hashtags.slice(0, 8).map((h, i) => (
                  <span key={i} className="text-xs font-semibold text-pink-600 dark:text-pink-400 bg-pink-50 dark:bg-pink-900/20 px-2.5 py-1 rounded-full">
                    {h.startsWith('#') ? h : `#${h}`}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* ── Gallery section (from ad.detail) ────────────────────────────── */}
        <MobileSuggestedReelsSection
          reels={suggestedReels}
          loading={suggestedReelsLoading}
          onOpenReel={(id) => navigate(`/reels?id=${id}`)}
        />

        {galleryItems.length > 0 && (
          <AdGallerySection items={galleryItems} />
        )}

        {/* ── More from vendor ads grid ── */}
        {(vendorAds.length > 0 || vendorAdsLoading) && (
          <div className="hidden md:block mt-8">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm font-bold text-gray-900 dark:text-white">More from {vendorName}</p>
              {vendorId && (
                <Link to={`/vendor/${vendorId}/public`} className="flex items-center gap-1 text-xs font-bold text-pink-600 dark:text-pink-400 hover:underline">
                  See all <ChevronRight size={13} />
                </Link>
              )}
            </div>
            {vendorAdsLoading ? (
              <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2">
                {[...Array(6)].map((_, i) => (
                  <div key={i} className="rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '9/16' }} />
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2">
                {vendorAds.map(va => (
                  <MiniAdCard key={va._id} ad={va} onClick={(id) => navigate(`/ads/${id}/details`)} />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
