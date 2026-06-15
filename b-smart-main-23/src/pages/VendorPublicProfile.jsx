import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Swiper, SwiperSlide } from 'swiper/react';
import { Autoplay, Pagination } from 'swiper/modules';
import 'swiper/css';
import 'swiper/css/pagination';
import api from '../lib/api';
import {
  ArrowLeft, BadgeCheck, MapPin, Globe, Phone, Mail,
  UserPlus, UserCheck, Heart, Eye, Play, ShoppingBag, Film,
  MessageSquare, Building2, Tag, ChevronRight, Image as ImageIcon,
  Info, CalendarDays, Package,
} from 'lucide-react';

const IcoInstagram = ({ size = 16, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <rect x="2" y="2" width="20" height="20" rx="5" ry="5" />
    <circle cx="12" cy="12" r="4.5" />
    <circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none" />
  </svg>
);

const IcoFacebook = ({ size = 16, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" />
  </svg>
);

const IcoLinkedin = ({ size = 16, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z" />
    <rect x="2" y="9" width="4" height="12" />
    <circle cx="4" cy="4" r="2" />
  </svg>
);

const IcoTwitterX = ({ size = 16, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
  </svg>
);

const BASE_URL = 'https://api.bebsmart.in';

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

const fmt = (n = 0) => {
  if (!n) return '0';
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

// ─── Mini Ad Card ─────────────────────────────────────────────────────────────
const MiniAdCard = ({ ad, onClick }) => {
  const media = ad.media?.[0];
  const thumb = media?.media_type === 'video'
    ? toAbsoluteUploadUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url)
    : toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);
  const isVid = media?.media_type === 'video';

  return (
    <button
      onClick={() => onClick(ad._id)}
      className="relative overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 group cursor-pointer w-full"
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

// ─── Detail Row ───────────────────────────────────────────────────────────────
const DetailRow = ({ icon, label, value, href, external }) => {
  const inner = (
    <div className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-800/60 transition-colors group">
      <div className="w-9 h-9 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center flex-shrink-0">
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest leading-none mb-0.5">{label}</p>
        <p className="text-sm font-semibold text-gray-800 dark:text-gray-100 truncate">{value}</p>
      </div>
      {href && <ChevronRight size={14} className="text-gray-300 group-hover:text-gray-400 transition-colors flex-shrink-0" />}
    </div>
  );
  if (href) {
    return <a href={href} {...(external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}>{inner}</a>;
  }
  return inner;
};

const TABS = ['About', 'Products', 'Gallery', 'Ads', 'Events', 'Locations', 'Contact'];

export default function VendorPublicProfile() {
  const { vendorId } = useParams();
  const navigate = useNavigate();
  const { userObject } = useSelector(s => s.auth);

  const [profile, setProfile]   = useState(null);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState('');
  const [activeTab, setActiveTab] = useState('About');

  const [ads, setAds]               = useState([]);
  const [adsLoading, setAdsLoading] = useState(false);
  const [adsFetched, setAdsFetched] = useState(false);

  const [gallery, setGallery]               = useState([]);
  const [galleryLoading, setGalleryLoading] = useState(false);
  const [galleryFetched, setGalleryFetched] = useState(false);

  const [followed, setFollowed]         = useState(false);
  const [followLoading, setFollowLoading] = useState(false);

  const tabBarRef = useRef(null);

  // ── Fetch vendor profile ───────────────────────────────────────────────────
  useEffect(() => {
    if (!vendorId) return;
    setLoading(true);
    api.get(`/vendors/profile/${vendorId}/public`)
      .then(res => {
        const data = res.data?.vendor || res.data?.data || res.data;
        setProfile(data);
        setFollowed(data?.is_following || false);
      })
      .catch(() => setError('Could not load vendor profile.'))
      .finally(() => setLoading(false));
  }, [vendorId]);

  // ── Fetch ads (lazy on tab open) ──────────────────────────────────────────
  useEffect(() => {
    if (activeTab !== 'Ads' || !profile || adsFetched) return;
    const uid = profile.user_id?._id || profile._id;
    if (!uid) return;
    setAdsLoading(true);
    setAdsFetched(true);
    api.get(`/ads/user/${uid}`)
      .then(res => {
        const list = Array.isArray(res.data) ? res.data : res.data?.ads || res.data?.data || [];
        setAds(list);
      })
      .catch(() => {})
      .finally(() => setAdsLoading(false));
  }, [activeTab, profile, adsFetched]);

  // ── Fetch gallery (lazy on tab open) ──────────────────────────────────────
  useEffect(() => {
    if (activeTab !== 'Gallery' || galleryFetched) return;
    setGalleryLoading(true);
    setGalleryFetched(true);
    api.get('/ads/gallery')
      .then(res => {
        const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
        setGallery(list);
      })
      .catch(() => {})
      .finally(() => setGalleryLoading(false));
  }, [activeTab, galleryFetched]);

  // ── Follow toggle ─────────────────────────────────────────────────────────
  const toggleFollow = async () => {
    if (!userObject || followLoading) return;
    const wasFollowed = followed;
    setFollowLoading(true);
    setFollowed(!wasFollowed);
    try {
      if (wasFollowed) {
        await api.delete(`/vendor/${vendorId}/follow`);
      } else {
        await api.post(`/vendor/${vendorId}/follow`);
      }
    } catch {
      setFollowed(wasFollowed);
    } finally {
      setFollowLoading(false);
    }
  };

  // ── Loading / Error states ────────────────────────────────────────────────
  if (loading) return (
    <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
      <div className="w-10 h-10 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );

  if (error || !profile) return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-4 p-6">
      <p className="text-gray-500 dark:text-gray-400">{error || 'Profile not found.'}</p>
      <button onClick={() => navigate(-1)} className="text-pink-600 font-bold text-sm hover:underline">← Go Back</button>
    </div>
  );

  // ── Derived values ────────────────────────────────────────────────────────
  const coverImages    = (profile.cover_image_urls || []).map(toAbsoluteUploadUrl).filter(Boolean);
  const avatarUrl      = toAbsoluteUploadUrl(profile.user_id?.avatar_url || '');
  const businessName   = profile.business_name || profile.company_details?.company_name || profile.user_id?.full_name || 'Vendor';
  const isVerified     = profile.validated === true;
  const followerCount  = profile.follower_count || 0;
  const followingCount = profile.following_count || 0;
  const adCount        = profile.ad_count || 0;
  const op             = profile.online_presence || {};
  const sm             = profile.social_media_links || {};

  // ── Tab: About ────────────────────────────────────────────────────────────
  const renderAbout = () => (
    <div className="space-y-3 px-4 py-4 max-w-2xl mx-auto lg:px-0">
      {profile.company_description && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 border border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-2 mb-3">
            <Info size={14} className="text-blue-500" />
            <p className="text-sm font-bold text-gray-900 dark:text-white">About</p>
          </div>
          <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{profile.company_description}</p>
        </div>
      )}

      {profile.company_details && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 border border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-2 mb-4">
            <Building2 size={14} className="text-purple-500" />
            <p className="text-sm font-bold text-gray-900 dark:text-white">Company Details</p>
          </div>
          <div className="grid grid-cols-2 gap-2.5">
            {[
              { label: 'Company',   value: profile.company_details.company_name },
              { label: 'Industry',  value: profile.company_details.industry },
              { label: 'Type',      value: profile.company_details.company_type },
              { label: 'Est. Year', value: profile.company_details.year_established },
              { label: 'Reg. No',   value: profile.company_details.registration_number },
              { label: 'Tax ID',    value: profile.company_details.tax_id },
            ].filter(i => i.value).map((item, idx) => (
              <div key={idx} className="flex flex-col gap-0.5 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{item.label}</span>
                <span className="text-xs font-bold text-gray-800 dark:text-gray-100">{item.value}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {profile.business_details && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 border border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-2 mb-4">
            <Tag size={14} className="text-amber-500" />
            <p className="text-sm font-bold text-gray-900 dark:text-white">Business Details</p>
          </div>
          <div className="grid grid-cols-2 gap-2.5">
            {[
              { label: 'Category', value: profile.business_details.industry_category },
              { label: 'Nature',   value: profile.business_details.business_nature },
              { label: 'Coverage', value: profile.business_details.service_coverage },
              { label: 'Country',  value: profile.business_details.country },
            ].filter(i => i.value).map((item, idx) => (
              <div key={idx} className="flex flex-col gap-0.5 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{item.label}</span>
                <span className="text-xs font-bold text-gray-800 dark:text-gray-100">{item.value}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );

  // ── Tab: Products ─────────────────────────────────────────────────────────
  const renderProducts = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0">
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        {[...Array(6)].map((_, i) => (
          <div key={i} className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden">
            <div className="w-full aspect-square bg-gradient-to-br from-orange-50 to-pink-50 dark:from-orange-900/20 dark:to-pink-900/20 flex items-center justify-center">
              <Package size={32} className="text-orange-200 dark:text-orange-700" />
            </div>
            <div className="p-3 space-y-1.5">
              <div className="h-2.5 bg-gray-100 dark:bg-gray-800 rounded-full w-3/4 animate-pulse" />
              <div className="h-2 bg-gray-100 dark:bg-gray-800 rounded-full w-1/2 animate-pulse" />
              <div className="h-4 bg-gray-100 dark:bg-gray-800 rounded-full w-1/3 animate-pulse" />
            </div>
          </div>
        ))}
      </div>
      <p className="text-center text-xs text-gray-400 mt-5 py-2">Products coming soon</p>
    </div>
  );

  // ── Tab: Gallery ──────────────────────────────────────────────────────────
  const renderGallery = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0">
      {galleryLoading ? (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {[...Array(9)].map((_, i) => (
            <div key={i} className="rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '1/1' }} />
          ))}
        </div>
      ) : gallery.length === 0 ? (
        <div className="text-center py-16">
          <ImageIcon size={40} className="mx-auto mb-3 text-gray-300 dark:text-gray-600" />
          <p className="text-sm text-gray-400">No gallery items yet</p>
        </div>
      ) : (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {gallery.map((item, idx) => {
            const url   = toAbsoluteUploadUrl(item.link || item.fileUrl || item.url || '');
            const fname = item.filename || item.filname || '';
            if (!url) return null;
            return (
              <div
                key={item.adId || idx}
                className="rounded-xl overflow-hidden bg-gray-100 dark:bg-gray-800 cursor-pointer group"
                style={{ aspectRatio: '1/1' }}
              >
                <img
                  src={url}
                  alt={fname}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  onError={e => { e.currentTarget.style.display = 'none'; }}
                />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );

  // ── Tab: Ads ──────────────────────────────────────────────────────────────
  const renderAds = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0">
      {adsLoading ? (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {[...Array(8)].map((_, i) => (
            <div key={i} className="rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '9/16' }} />
          ))}
        </div>
      ) : ads.length === 0 ? (
        <div className="text-center py-16">
          <Film size={40} className="mx-auto mb-3 text-gray-300 dark:text-gray-600" />
          <p className="text-sm text-gray-400">No ads yet</p>
        </div>
      ) : (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {ads.map(ad => (
            <MiniAdCard key={ad._id} ad={ad} onClick={(id) => navigate(`/ads/${id}/details`)} />
          ))}
        </div>
      )}
    </div>
  );

  // ── Tab: Events ───────────────────────────────────────────────────────────
  const renderEvents = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0 space-y-3">
      {[
        { title: 'Annual Sale Event',  date: 'Coming Soon', desc: 'Exciting deals and offers awaiting you',   gradient: 'from-orange-400 to-pink-500' },
        { title: 'New Product Launch', date: 'TBA',         desc: 'New collection unveiling ceremony',        gradient: 'from-purple-400 to-indigo-500' },
        { title: 'Flash Sale',         date: 'TBA',         desc: 'Limited time offers, huge discounts',      gradient: 'from-green-400 to-teal-500' },
      ].map((ev, i) => (
        <div key={i} className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden flex items-stretch">
          <div className={`w-1.5 bg-gradient-to-b ${ev.gradient} flex-shrink-0`} />
          <div className="p-4 flex items-start gap-3 flex-1">
            <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${ev.gradient} flex items-center justify-center flex-shrink-0`}>
              <CalendarDays size={16} className="text-white" />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between gap-2">
                <p className="text-sm font-bold text-gray-900 dark:text-white">{ev.title}</p>
                <span className="text-[10px] font-bold text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full flex-shrink-0">{ev.date}</span>
              </div>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{ev.desc}</p>
            </div>
          </div>
        </div>
      ))}
      <div className="text-center py-4">
        <p className="text-xs text-gray-400">More events will be announced soon</p>
      </div>
    </div>
  );

  // ── Tab: Locations ────────────────────────────────────────────────────────
  const renderLocations = () => {
    const addr = op.address;
    return (
      <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0 space-y-3">
        {addr && (
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5">
            <div className="flex items-center gap-2 mb-4">
              <MapPin size={14} className="text-rose-500" />
              <p className="text-sm font-bold text-gray-900 dark:text-white">Primary Location</p>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-rose-50 dark:bg-rose-900/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                <MapPin size={18} className="text-rose-500" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-800 dark:text-gray-100">
                  {[addr.address_line1, addr.address_line2].filter(Boolean).join(', ')}
                </p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                  {[addr.city, addr.state, addr.pincode].filter(Boolean).join(', ')}
                </p>
                <p className="text-xs text-gray-400">{addr.country}</p>
              </div>
            </div>
          </div>
        )}

        {/* Map placeholder */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden">
          <div className="w-full h-52 bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-800 dark:to-gray-700 flex flex-col items-center justify-center gap-2.5">
            <div className="w-12 h-12 rounded-full bg-white dark:bg-gray-700 shadow flex items-center justify-center">
              <MapPin size={24} className="text-rose-400" />
            </div>
            <p className="text-xs text-gray-400 font-semibold">Map view coming soon</p>
          </div>
        </div>
      </div>
    );
  };

  // ── Tab: Contact ──────────────────────────────────────────────────────────
  const renderContact = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0 space-y-3">
      <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden">
        <div className="px-5 pt-5 pb-2">
          <p className="text-sm font-bold text-gray-900 dark:text-white">Contact Information</p>
        </div>
        <div className="px-2 pb-2">
          {op.phone_number && (
            <DetailRow
              icon={<Phone size={16} className="text-blue-500" />}
              label="Phone"
              value={op.phone_number}
              href={`tel:${op.phone_number}`}
            />
          )}
          {op.company_email && (
            <DetailRow
              icon={<Mail size={16} className="text-purple-500" />}
              label="Email"
              value={op.company_email}
              href={`mailto:${op.company_email}`}
            />
          )}
          {op.website_url && (
            <DetailRow
              icon={<Globe size={16} className="text-emerald-500" />}
              label="Website"
              value={op.website_url}
              href={op.website_url}
              external
            />
          )}
          {op.address?.city && (
            <DetailRow
              icon={<MapPin size={16} className="text-rose-500" />}
              label="Location"
              value={[op.address.city, op.address.state, op.address.country].filter(Boolean).join(', ')}
            />
          )}
        </div>
      </div>

      {/* WhatsApp CTA */}
      {op.phone_number && (
        <a
          href={`https://wa.me/${op.phone_number.replace(/\D/g, '')}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center gap-2.5 w-full py-3.5 rounded-2xl bg-gradient-to-r from-green-500 to-emerald-600 text-white font-bold text-sm shadow-lg hover:opacity-90 active:scale-[0.98] transition-all"
        >
          <MessageSquare size={16} /> Chat on WhatsApp
        </a>
      )}

      {/* Social Media */}
      {Object.values(sm).some(Boolean) && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5">
          <p className="text-sm font-bold text-gray-900 dark:text-white mb-4">Social Media</p>
          <div className="grid grid-cols-2 gap-2">
            {sm.instagram && (
              <a href={sm.instagram} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-2.5 p-3 rounded-xl border border-pink-100 dark:border-pink-900/30 bg-pink-50 dark:bg-pink-900/10 hover:bg-pink-100 dark:hover:bg-pink-900/20 transition-colors">
                <IcoInstagram size={16} className="text-pink-500 flex-shrink-0" />
                <span className="text-xs font-bold text-pink-700 dark:text-pink-400">Instagram</span>
              </a>
            )}
            {sm.facebook && (
              <a href={sm.facebook} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-2.5 p-3 rounded-xl border border-blue-100 dark:border-blue-900/30 bg-blue-50 dark:bg-blue-900/10 hover:bg-blue-100 dark:hover:bg-blue-900/20 transition-colors">
                <IcoFacebook size={16} className="text-blue-600 flex-shrink-0" />
                <span className="text-xs font-bold text-blue-700 dark:text-blue-400">Facebook</span>
              </a>
            )}
            {sm.linkedin && (
              <a href={sm.linkedin} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-2.5 p-3 rounded-xl border border-indigo-100 dark:border-indigo-900/30 bg-indigo-50 dark:bg-indigo-900/10 hover:bg-indigo-100 dark:hover:bg-indigo-900/20 transition-colors">
                <IcoLinkedin size={16} className="text-indigo-600 flex-shrink-0" />
                <span className="text-xs font-bold text-indigo-700 dark:text-indigo-400">LinkedIn</span>
              </a>
            )}
            {sm.twitter && (
              <a href={sm.twitter} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-2.5 p-3 rounded-xl border border-sky-100 dark:border-sky-900/30 bg-sky-50 dark:bg-sky-900/10 hover:bg-sky-100 dark:hover:bg-sky-900/20 transition-colors">
                <IcoTwitterX size={16} className="text-sky-500 flex-shrink-0" />
                <span className="text-xs font-bold text-sky-700 dark:text-sky-400">X (Twitter)</span>
              </a>
            )}
          </div>
        </div>
      )}
    </div>
  );

  const tabContent = {
    About:     renderAbout(),
    Products:  renderProducts(),
    Gallery:   renderGallery(),
    Ads:       renderAds(),
    Events:    renderEvents(),
    Locations: renderLocations(),
    Contact:   renderContact(),
  };

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 font-sans">

      {/* ── Floating back button ───────────────────────────────────── */}
      <div className="absolute top-0 left-0 right-0 z-50 pointer-events-none">
        <div className="max-w-2xl mx-auto lg:max-w-4xl px-4 pt-3 pointer-events-auto">
          <button
            onClick={() => navigate(-1)}
            className="w-9 h-9 rounded-full bg-black/40 backdrop-blur-sm flex items-center justify-center text-white hover:bg-black/60 transition-colors shadow"
          >
            <ArrowLeft size={18} />
          </button>
        </div>
      </div>

      {/* ── Cover carousel ────────────────────────────────────────── */}
      <div className="relative w-full" style={{ height: 240 }}>
        {coverImages.length > 0 ? (
          <Swiper
            modules={[Autoplay, Pagination]}
            autoplay={{ delay: 4500, disableOnInteraction: false }}
            pagination={{ clickable: true }}
            loop={coverImages.length > 1}
            className="w-full h-full"
          >
            {coverImages.map((url, i) => (
              <SwiperSlide key={i}>
                <img src={url} alt={`Cover ${i + 1}`} className="w-full h-full object-cover" />
              </SwiperSlide>
            ))}
          </Swiper>
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent pointer-events-none" />
      </div>

      {/* ── Profile identity block ─────────────────────────────────── */}
      <div className="bg-white dark:bg-gray-900 border-b border-gray-100 dark:border-gray-800">
        <div className="max-w-2xl mx-auto lg:max-w-4xl px-4">

          {/* Avatar row */}
          <div className="flex items-end justify-between -mt-12 mb-3">
            <div className="w-24 h-24 rounded-full border-4 border-white dark:border-gray-900 overflow-hidden bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center flex-shrink-0 shadow-lg">
              {avatarUrl ? (
                <img src={avatarUrl} alt={businessName} className="w-full h-full object-cover" />
              ) : (
                <span className="text-white font-black text-3xl select-none">{businessName[0]}</span>
              )}
            </div>
            <button
              onClick={toggleFollow}
              disabled={followLoading}
              className={`flex items-center gap-1.5 px-5 py-2.5 rounded-xl font-bold text-sm transition-all active:scale-[0.97] shadow-sm ${
                followed
                  ? 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700'
                  : 'bg-blue-600 hover:bg-blue-700 text-white'
              }`}
            >
              {followed ? <UserCheck size={15} /> : <UserPlus size={15} />}
              {followed ? 'Following' : '+ Follow'}
            </button>
          </div>

          {/* Name + verified */}
          <div className="flex items-center gap-2 mb-1 flex-wrap">
            <h1 className="text-xl font-black text-gray-900 dark:text-white leading-tight">{businessName}</h1>
            {isVerified && (
              <span className="w-5 h-5 rounded-full bg-[#0095f6] flex items-center justify-center flex-shrink-0">
                <BadgeCheck size={11} className="text-white" strokeWidth={3} />
              </span>
            )}
          </div>

          {/* Username + category */}
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-2">
            @{profile.user_id?.username || 'vendor'}
            {profile.business_details?.industry_category && (
              <> &middot; <span>{profile.business_details.industry_category}</span></>
            )}
          </p>

          {/* Nature */}
          {profile.business_details?.business_nature && (
            <div className="flex items-center gap-1.5 mb-3">
              <Building2 size={12} className="text-gray-400" />
              <span className="text-xs text-gray-500 dark:text-gray-400 font-medium">{profile.business_details.business_nature}</span>
            </div>
          )}

          {/* Stats */}
          <div className="flex items-center gap-0 py-3 border-t border-gray-100 dark:border-gray-800 -mx-4 px-4">
            <div className="flex-1 flex flex-col items-center py-1">
              <span className="text-base font-black text-gray-900 dark:text-white">{fmt(followerCount)}</span>
              <span className="text-[11px] text-gray-500 dark:text-gray-400">followers</span>
            </div>
            <div className="w-px h-8 bg-gray-100 dark:bg-gray-800" />
            <div className="flex-1 flex flex-col items-center py-1">
              <span className="text-base font-black text-gray-900 dark:text-white">{fmt(followingCount)}</span>
              <span className="text-[11px] text-gray-500 dark:text-gray-400">following</span>
            </div>
            <div className="w-px h-8 bg-gray-100 dark:bg-gray-800" />
            <div className="flex-1 flex flex-col items-center py-1">
              <span className="text-base font-black text-gray-900 dark:text-white">{fmt(adCount)}</span>
              <span className="text-[11px] text-gray-500 dark:text-gray-400">ads</span>
            </div>
          </div>
        </div>

        {/* ── Tab bar ─────────────────────────────────────────────── */}
        <div
          ref={tabBarRef}
          className="overflow-x-auto"
          style={{ scrollbarWidth: 'none' }}
        >
          <div className="flex min-w-max max-w-2xl lg:max-w-4xl mx-auto px-4 border-t border-gray-100 dark:border-gray-800">
            {TABS.map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-4 py-3.5 text-xs font-bold tracking-wide whitespace-nowrap border-b-2 transition-colors ${
                  activeTab === tab
                    ? 'border-blue-600 text-blue-600 dark:text-blue-400 dark:border-blue-400'
                    : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ── Tab content ───────────────────────────────────────────── */}
      <div className="max-w-2xl lg:max-w-4xl mx-auto pb-10">
        {tabContent[activeTab]}
      </div>

    </div>
  );
}
