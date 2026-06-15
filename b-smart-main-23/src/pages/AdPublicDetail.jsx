import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import api from '../lib/api';
import {
  ArrowLeft, Heart, MessageCircle,
  Globe, Phone, Mail, MessageSquare, ExternalLink,
  MapPin, Tag, Play, Volume2, VolumeX, BadgeCheck,
  ShoppingBag, Eye, ChevronRight, ChevronLeft, X, Film,
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

// ─── Comment Avatar ──────────────────────────────────────────────────────────
const CommentAvatar = ({ name = '', url = '' }) => {
  if (url) return <img src={toAbsoluteUploadUrl(url)} alt={name} className="w-8 h-8 rounded-full object-cover flex-shrink-0" />;
  const initials = (name.trim().split(/\s+/).map(p => p[0]).slice(0, 2).join('') || 'U').toUpperCase();
  const hue = name.split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return (
    <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-[11px] font-bold flex-shrink-0"
      style={{ background: `hsl(${hue},60%,50%)` }}>
      {initials}
    </div>
  );
};

export default function AdPublicDetail() {
  const { adId }       = useParams();
  const navigate       = useNavigate();
  const { userObject } = useSelector(s => s.auth);

  const [ad, setAd]           = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState('');
  const [isMuted, setIsMuted] = useState(true);
  const [imgError, setImgError] = useState(false);

  const [liked, setLiked]             = useState(false);
  const [likesCount, setLikesCount]   = useState(0);
  const [likeLoading, setLikeLoading] = useState(false);

  const [comments, setComments]           = useState([]);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [commentsPage, setCommentsPage]   = useState(1);
  const [commentsTotal, setCommentsTotal] = useState(0);
  const COMMENTS_PER_PAGE = 5;

  const [vendorAds, setVendorAds]               = useState([]);
  const [vendorAdsLoading, setVendorAdsLoading] = useState(false);

  // Fetch ad
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

  // Fetch comments
  useEffect(() => {
    if (!adId) return;
    setCommentsLoading(true);
    api.get(`/ads/${adId}/comments`, { params: { page: commentsPage, limit: COMMENTS_PER_PAGE } })
      .then(res => {
        const data  = Array.isArray(res.data) ? res.data : res.data?.comments || res.data?.data || [];
        const total = res.data?.total || res.data?.totalCount || data.length;
        setComments(data);
        setCommentsTotal(total);
      })
      .catch(() => setComments([]))
      .finally(() => setCommentsLoading(false));
  }, [adId, commentsPage]);

  // Fetch vendor ads
  useEffect(() => {
    if (!ad) return;
    const uid = ad.user_id?._id || ad.vendor_id?._id;
    if (!uid) return;
    setVendorAdsLoading(true);
    api.get(`/ads/user/${uid}`)
      .then(res => {
        const list = Array.isArray(res.data) ? res.data : res.data?.ads || res.data?.data || [];
        setVendorAds(list.filter(a => a._id !== adId).slice(0, 8));
      })
      .catch(() => {})
      .finally(() => setVendorAdsLoading(false));
  }, [ad, adId]);

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
    <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
      <div className="w-10 h-10 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );

  if (error || !ad) return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-4 p-6">
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
  const totalPages   = Math.max(1, Math.ceil(commentsTotal / COMMENTS_PER_PAGE));

  const galleryItems = Array.isArray(ad.gallery) && ad.gallery.length > 0
    ? ad.gallery
    : Array.isArray(ad.detail) && ad.detail.length > 0 ? ad.detail : [];

  const highlights = [
    ad.category  && { label: 'Category', value: ad.category,                      icon: <Tag size={13} className="text-violet-500" />,     bg: 'bg-violet-50 dark:bg-violet-950/30 border-violet-100 dark:border-violet-900/20' },
    ad.location  && { label: 'Location', value: ad.location,                      icon: <MapPin size={13} className="text-rose-500" />,     bg: 'bg-rose-50 dark:bg-rose-950/30 border-rose-100 dark:border-rose-900/20' },
    ad.ad_type   && { label: 'Type',     value: ad.ad_type.replace('_', ' '),     icon: <Play size={13} className="text-amber-500" />,      bg: 'bg-amber-50 dark:bg-amber-950/30 border-amber-100 dark:border-amber-900/20' },
    ad.target_language?.length > 0 && { label: 'Language', value: ad.target_language.slice(0, 2).join(', '), icon: <Globe size={13} className="text-blue-500" />, bg: 'bg-blue-50 dark:bg-blue-950/30 border-blue-100 dark:border-blue-900/20' },
    ad.status    && { label: 'Status',   value: ad.status,                        icon: <BadgeCheck size={13} className="text-emerald-500" />, bg: 'bg-emerald-50 dark:bg-emerald-950/30 border-emerald-100 dark:border-emerald-900/20' },
  ].filter(Boolean);

  /* ── Shared Comments Block ─────────────────────────────────────────────── */
  const commentsBlock = (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm font-bold text-gray-900 dark:text-white flex items-center gap-2">
          <MessageCircle size={15} className="text-purple-500" />
          Comments
          <span className="text-xs font-semibold text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full">
            {fmt(ad.comments_count || 0)}
          </span>
        </p>
        <button onClick={toggleLike} className="flex items-center gap-1.5 text-sm font-bold">
          <Heart size={16} className={liked ? 'text-pink-500 fill-pink-500' : 'text-gray-400'} />
          <span className={liked ? 'text-pink-500' : 'text-gray-500 dark:text-gray-400'}>{fmt(likesCount)}</span>
        </button>
      </div>

      {/* List */}
      {commentsLoading ? (
        <div className="flex items-center justify-center py-8 gap-2 text-gray-400">
          <div className="w-4 h-4 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm">Loading…</span>
        </div>
      ) : comments.length === 0 ? (
        <div className="text-center py-8 text-gray-400">
          <MessageCircle size={28} className="mx-auto mb-2 opacity-30" />
          <p className="text-sm">No comments yet</p>
        </div>
      ) : (
        <div className="space-y-3">
          {comments.map((c, i) => {
            const u    = c.user_id || c.user || {};
            const name = u.full_name || u.username || 'User';
            const date = c.createdAt ? new Date(c.createdAt).toLocaleDateString('en-IN', { dateStyle: 'medium' }) : '';
            return (
              <div key={c._id || i} className="flex gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                <CommentAvatar name={name} url={u.avatar_url || ''} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <span className="text-xs font-bold text-gray-900 dark:text-white truncate">{name}</span>
                    <span className="text-[10px] text-gray-400 shrink-0">{date}</span>
                  </div>
                  <p className="text-xs text-gray-600 dark:text-gray-300 leading-relaxed">
                    {c.text || c.content || c.comment || ''}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 pt-4 border-t border-gray-100 dark:border-gray-800">
          <button onClick={() => setCommentsPage(p => Math.max(1, p - 1))}
            disabled={commentsPage === 1 || commentsLoading}
            className="px-4 py-2 rounded-xl text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
            ← Prev
          </button>
          <span className="text-xs text-gray-400">Page {commentsPage} / {totalPages}</span>
          <button onClick={() => setCommentsPage(p => Math.min(totalPages, p + 1))}
            disabled={commentsPage === totalPages || commentsLoading}
            className="px-4 py-2 rounded-xl text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
            Next →
          </button>
        </div>
      )}
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 font-sans">

      {/* ── Sticky Header ─────────────────────────────────────────── */}
      <div className="sticky top-0 z-40 bg-white/95 dark:bg-black/95 backdrop-blur-md border-b border-gray-100 dark:border-gray-800">
        <div className="max-w-6xl mx-auto px-4 h-14 flex items-center gap-3">
          <button onClick={() => navigate(-1)}
            className="w-9 h-9 rounded-full flex items-center justify-center hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors shrink-0">
            <ArrowLeft size={20} className="text-gray-800 dark:text-white" />
          </button>
          <div className="flex items-center gap-2 flex-1 min-w-0">
            {vendorAvatar
              ? <img src={toAbsoluteUploadUrl(vendorAvatar)} className="w-7 h-7 rounded-full object-cover shrink-0" alt={vendorName} />
              : <div className="w-7 h-7 rounded-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white text-xs font-bold shrink-0">{vendorName[0]}</div>
            }
            <span className="text-sm font-bold text-gray-900 dark:text-white truncate">{vendorName}</span>
            {isVerified && (
              <span className="w-4 h-4 rounded-full bg-[#0095f6] flex items-center justify-center shrink-0">
                <BadgeCheck size={9} className="text-white" strokeWidth={3} />
              </span>
            )}
          </div>
          <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full border shrink-0 ${
            ad.status === 'active'
              ? 'bg-emerald-50 text-emerald-600 border-emerald-200 dark:bg-emerald-900/20 dark:text-emerald-400 dark:border-emerald-900/30'
              : 'bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-700'
          }`}>{ad.status}</span>
        </div>
      </div>

      {/* ── Page Body ─────────────────────────────────────────────── */}
      <div className="max-w-6xl mx-auto lg:px-6 lg:py-6 pb-16">
        <div className="lg:grid lg:grid-cols-[1fr_360px] lg:gap-6 lg:items-start">

          {/* ════ LEFT / MAIN ═══════════════════════════════════════ */}
          <div className="space-y-2 lg:space-y-4">

            {/* 1. Hero media */}
            <div className="flex justify-center bg-gray-100 dark:bg-gray-900 lg:rounded-2xl overflow-hidden py-4 lg:py-6">
              <div
                className="rounded-2xl overflow-hidden shadow-xl"
                style={{ width: isVideo ? 280 : 'auto', maxWidth: '95%' }}
              >
                {isVideo ? (
                  <VideoPlayer src={videoSrc} thumb={thumbSrc} muted={isMuted} onToggleMute={() => setIsMuted(m => !m)} />
                ) : (imageSrc && !imgError) ? (
                  <img
                    src={imageSrc}
                    alt={ad.ad_title || ''}
                    className="block max-w-full"
                    style={{ maxHeight: '70vh', width: 'auto', height: 'auto' }}
                    onError={() => setImgError(true)}
                  />
                ) : (
                  <div className="w-[280px] flex items-center justify-center py-16 bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600">
                    <p className="text-white font-bold text-xl text-center px-6">{vendorName}</p>
                  </div>
                )}
              </div>
            </div>

            {/* 2. Info card */}
            <div className="bg-white dark:bg-gray-900 lg:rounded-2xl lg:border lg:border-gray-100 lg:dark:border-gray-800 px-4 pt-4 pb-4 lg:p-5">

              {/* Vendor row */}
              <div className="flex items-center gap-3 mb-3">
                <Link to={`/vendor/${vendorId}/public`}
                  className="w-10 h-10 rounded-full overflow-hidden shrink-0 bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white font-bold text-sm">
                  {vendorAvatar
                    ? <img src={toAbsoluteUploadUrl(vendorAvatar)} alt={vendorName} className="w-full h-full object-cover" />
                    : vendorName[0]}
                </Link>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5">
                    <Link to={`/vendor/${vendorId}/public`} className="text-sm font-bold text-gray-900 dark:text-white truncate hover:underline">
                      {vendorName}
                    </Link>
                    {isVerified && (
                      <span className="w-4 h-4 rounded-full bg-[#0095f6] flex items-center justify-center shrink-0">
                        <BadgeCheck size={9} className="text-white" strokeWidth={3} />
                      </span>
                    )}
                  </div>
                  <span className="text-xs text-gray-400">@{ad.user_id?.username || 'vendor'}</span>
                </div>
                <Link to={`/vendor/${vendorId}/public`}
                  className="shrink-0 text-xs font-bold text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-gray-700 px-3 py-1.5 rounded-full hover:border-gray-300 transition-colors">
                  View Profile
                </Link>
              </div>

              {/* Title */}
              {ad.ad_title && (
                <h1 className="text-lg font-extrabold text-gray-900 dark:text-white leading-snug mb-2">{ad.ad_title}</h1>
              )}

              {/* Description */}
              {ad.ad_description && (
                <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed mb-3">{ad.ad_description}</p>
              )}

              {/* CTA */}
              {ad.cta?.type && (
                <div className="mb-3">
                  <CtaButton cta={ad.cta} adId={adId} />
                </div>
              )}

              {/* Contact chips */}
              {(ad.cta?.whatsapp_number || ad.cta?.phone_number || ad.cta?.email) && (
                <div className="flex gap-2 flex-wrap mb-3">
                  {ad.cta?.whatsapp_number && (
                    <a href={`https://wa.me/${ad.cta.whatsapp_number.replace(/\D/g, '')}`} target="_blank" rel="noopener noreferrer"
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

              {/* Engagement stats */}
              <div className="flex items-center gap-5 pt-3 border-t border-gray-100 dark:border-gray-800">
                <button onClick={toggleLike} className="flex items-center gap-1.5 text-sm font-bold transition-colors">
                  <Heart size={18} className={liked ? 'text-pink-500 fill-pink-500' : 'text-gray-400'} />
                  <span className={liked ? 'text-pink-500' : 'text-gray-600 dark:text-gray-400'}>{fmt(likesCount)}</span>
                  <span className="text-xs text-gray-400">likes</span>
                </button>
                <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400">
                  <MessageCircle size={18} className="text-purple-400" />
                  <span className="font-bold text-gray-700 dark:text-gray-300">{fmt(ad.comments_count || 0)}</span>
                  <span className="text-xs">comments</span>
                </div>
                <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400">
                  <Eye size={18} className="text-blue-400" />
                  <span className="font-bold text-gray-700 dark:text-gray-300">{fmt(ad.views_count || 0)}</span>
                  <span className="text-xs">views</span>
                </div>
              </div>
            </div>

            {/* 3. Top Highlights */}
            {highlights.length > 0 && (
              <div className="bg-white dark:bg-gray-900 lg:rounded-2xl lg:border lg:border-gray-100 lg:dark:border-gray-800 px-4 py-4 lg:p-5">
                <p className="text-xs font-black text-gray-400 uppercase tracking-widest mb-3">Top Highlights</p>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {highlights.map((h, i) => (
                    <div key={i} className={`border rounded-xl p-3 flex flex-col gap-1.5 ${h.bg}`}>
                      {h.icon}
                      <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest leading-none">{h.label}</div>
                      <div className="text-xs font-bold text-gray-800 dark:text-gray-100 capitalize leading-tight">{h.value}</div>
                    </div>
                  ))}
                </div>

                {/* Caption / Hashtags */}
                {ad.caption && (
                  <p className="mt-4 text-sm text-gray-700 dark:text-gray-300 leading-relaxed border-t border-gray-100 dark:border-gray-800 pt-3">
                    {ad.caption.split('\n').slice(0, 4).join('\n')}
                  </p>
                )}
                {ad.hashtags?.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 mt-3">
                    {ad.hashtags.slice(0, 8).map((h, i) => (
                      <span key={i} className="text-xs font-semibold text-pink-600 dark:text-pink-400 bg-pink-50 dark:bg-pink-900/20 px-2.5 py-1 rounded-full">
                        {h.startsWith('#') ? h : `#${h}`}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* 4. Gallery */}
            {galleryItems.length > 0 && (
              <div className="bg-white dark:bg-gray-900 lg:rounded-2xl lg:border lg:border-gray-100 lg:dark:border-gray-800 px-4 py-4 lg:p-5">
                <div className="flex items-center gap-2 mb-3">
                  <Film size={15} className="text-pink-500" />
                  <p className="text-sm font-bold text-gray-900 dark:text-white flex-1">Gallery</p>
                  <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2.5 py-1 rounded-full font-semibold">
                    {galleryItems.length} items
                  </span>
                </div>
                <AdGallerySection items={galleryItems} />
              </div>
            )}

            {/* 5. More from vendor — mobile horizontal scroll */}
            {(vendorAds.length > 0 || vendorAdsLoading) && (
              <div className="bg-white dark:bg-gray-900 lg:hidden px-4 py-4">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-sm font-bold text-gray-900 dark:text-white">More from {vendorName}</p>
                  {vendorId && (
                    <Link to={`/vendor/${vendorId}/public`}
                      className="text-xs font-bold text-pink-600 dark:text-pink-400 flex items-center gap-1 hover:underline">
                      See all <ChevronRight size={13} />
                    </Link>
                  )}
                </div>
                <div className="flex gap-3 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
                  {vendorAdsLoading
                    ? [...Array(5)].map((_, i) => (
                      <div key={i} className="flex-shrink-0 w-[110px] rounded-2xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '9/16' }} />
                    ))
                    : vendorAds.map(va => (
                      <div key={va._id} className="flex-shrink-0 w-[110px]">
                        <MiniAdCard ad={va} onClick={(id) => navigate(`/ads/${id}/details`)} />
                      </div>
                    ))
                  }
                </div>
              </div>
            )}

            {/* 6. Comments — mobile */}
            <div className="bg-white dark:bg-gray-900 px-4 py-4 pb-6 lg:rounded-2xl lg:border lg:border-gray-100 lg:dark:border-gray-800 lg:p-5 lg:hidden">
              {commentsBlock}
            </div>

          </div>

          {/* ════ RIGHT / SIDEBAR (desktop only) ═══════════════════ */}
          <div className="hidden lg:flex flex-col gap-4">

            {/* Stats */}
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5">
              <p className="text-sm font-bold text-gray-900 dark:text-white mb-4">Engagement</p>
              <div className="grid grid-cols-3 gap-3">
                {[
                  { icon: Heart,         label: 'Likes',    value: fmt(likesCount),          cls: 'text-pink-500',   bg: 'bg-pink-50 dark:bg-pink-900/20',   action: toggleLike },
                  { icon: MessageCircle, label: 'Comments', value: fmt(ad.comments_count||0), cls: 'text-purple-500', bg: 'bg-purple-50 dark:bg-purple-900/20', action: null },
                  { icon: Eye,           label: 'Views',    value: fmt(ad.views_count||0),    cls: 'text-blue-500',   bg: 'bg-blue-50 dark:bg-blue-900/20',   action: null },
                ].map(s => (
                  <button key={s.label} onClick={s.action || undefined}
                    className={`flex flex-col items-center gap-1.5 p-3 rounded-xl ${s.bg} ${s.action ? 'cursor-pointer hover:opacity-80 transition-opacity' : ''}`}>
                    <s.icon size={20} className={s.label === 'Likes' && liked ? 'text-pink-500 fill-pink-500' : s.cls} />
                    <span className={`text-lg font-black ${s.cls}`}>{s.value}</span>
                    <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wide">{s.label}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* More from vendor — desktop grid */}
            {(vendorAds.length > 0 || vendorAdsLoading) && (
              <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5">
                <div className="flex items-center justify-between mb-4">
                  <p className="text-sm font-bold text-gray-900 dark:text-white">More from {vendorName}</p>
                  {vendorId && (
                    <Link to={`/vendor/${vendorId}/public`}
                      className="text-xs font-bold text-pink-600 dark:text-pink-400 flex items-center gap-1 hover:underline">
                      See all <ChevronRight size={13} />
                    </Link>
                  )}
                </div>
                {vendorAdsLoading ? (
                  <div className="grid grid-cols-2 gap-2">
                    {[...Array(4)].map((_, i) => (
                      <div key={i} className="rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '9/16' }} />
                    ))}
                  </div>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    {vendorAds.slice(0, 4).map(va => (
                      <MiniAdCard key={va._id} ad={va} onClick={(id) => navigate(`/ads/${id}/details`)} />
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Comments — desktop */}
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5">
              {commentsBlock}
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}
