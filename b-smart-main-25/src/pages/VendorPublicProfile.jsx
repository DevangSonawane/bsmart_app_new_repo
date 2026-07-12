import { useState, useEffect, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Swiper, SwiperSlide } from 'swiper/react';
import { Autoplay, Pagination } from 'swiper/modules';
import 'swiper/css';
import 'swiper/css/pagination';
import api from '../lib/api';
import { checkFollowStatus, followUser, unfollowUser, FOLLOW_STATUS_CHANGED_EVENT } from '../services/followService';
import {
  ArrowLeft, BadgeCheck, MapPin, Globe, Phone, Mail,
  UserPlus, UserCheck, Heart, Eye, Play, ShoppingBag, Film,
  MessageSquare, Building2, Tag, ChevronRight, Image as ImageIcon,
  Info, CalendarDays, Package, Images, Megaphone, Calendar,
  MapPinned, Contact, Users, AtSign, Linkedin, Twitter, Facebook, Instagram
} from 'lucide-react';

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

const MiniAdCard = ({ ad, onClick }) => {
  const media = ad.media?.[0];
  const thumb = media?.media_type === 'video'
    ? toAbsoluteUploadUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url)
    : toAbsoluteUploadUrl(media?.fileUrl || media?.fileName);
  const isVid = media?.media_type === 'video';

  return (
    <button
      onClick={() => onClick(ad._id)}
      className="relative overflow-hidden rounded-2xl bg-gray-100 dark:bg-gray-800 group cursor-pointer w-full shadow-sm hover:shadow-lg transition-all duration-300"
      style={{ aspectRatio: '9/16' }}
    >
      {thumb ? (
        <img src={thumb} alt={ad.ad_title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
      ) : (
        <div className="w-full h-full bg-gradient-to-br from-orange-100 to-pink-100 dark:from-orange-900/30 dark:to-pink-900/30 flex items-center justify-center">
          <ShoppingBag size={24} className="text-orange-300" />
        </div>
      )}
      {isVid && (
        <div className="absolute top-2 right-2 w-6 h-6 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center">
          <Play size={10} className="text-white fill-white ml-0.5" />
        </div>
      )}
      <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col items-center justify-end pb-4 gap-1.5">
        <span className="flex items-center gap-1.5 text-white text-xs font-bold">
          <Heart size={12} className="fill-white" />{fmt(ad.likes_count || 0)}
        </span>
        <span className="flex items-center gap-1.5 text-white text-xs font-bold">
          <Eye size={12} />{fmt(ad.views_count || 0)}
        </span>
      </div>
    </button>
  );
};

const DetailRow = ({ icon, label, value, href, external }) => {
  const inner = (
    <div className="flex items-center gap-4 p-4 rounded-2xl hover:bg-gray-50 dark:hover:bg-gray-800/60 transition-all duration-200 group cursor-pointer">
      <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-700 flex items-center justify-center flex-shrink-0 shadow-sm">
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest leading-none mb-1.5">{label}</p>
        <p className="text-sm font-semibold text-gray-800 dark:text-gray-100 truncate">{value}</p>
      </div>
      {href && <ChevronRight size={16} className="text-gray-300 group-hover:text-gray-500 group-hover:translate-x-0.5 transition-all flex-shrink-0" />}
    </div>
  );
  if (href) {
    return <a href={href} {...(external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}>{inner}</a>;
  }
  return inner;
};

const TABS = [
  { id: 'About', label: 'About', icon: Info },
  { id: 'Products', label: 'Products', icon: Package },
  { id: 'Gallery', label: 'Gallery', icon: Images },
  { id: 'Ads', label: 'Spotlights', icon: Megaphone },
  { id: 'Events', label: 'Events', icon: Calendar },
  { id: 'Locations', label: 'Locations', icon: MapPinned },
  { id: 'Contact', label: 'Contact', icon: Contact },
];

export default function VendorPublicProfile() {
  const { vendorId } = useParams();
  const navigate = useNavigate();
  const { userObject } = useSelector(s => s.auth);

  const [profile, setProfile]     = useState(null);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState('');
  const [activeTab, setActiveTab] = useState('About');

  const [ads, setAds]               = useState([]);
  const [adsLoading, setAdsLoading] = useState(false);
  const [adsFetched, setAdsFetched] = useState(false);

  const [followState, setFollowState]     = useState('not_following');
  const [followLoading, setFollowLoading] = useState(false);
  const followed = followState === 'following';

  useEffect(() => {
    if (!vendorId) return;
    setLoading(true);
    api.get(`/vendors/profile/${vendorId}/public`)
      .then(res => {
        const data = res.data?.vendor || res.data?.data || res.data;
        setProfile(data);
      })
      .catch(() => setError('Could not load vendor profile.'))
      .finally(() => setLoading(false));
  }, [vendorId]);

  useEffect(() => {
    if ((activeTab !== 'Ads' && activeTab !== 'Gallery') || !profile || adsFetched) return;
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

  const galleryItems = useMemo(() => {
    return ads.flatMap(ad => {
      const items = [];
      (ad.media || []).forEach(m => {
        const url = toAbsoluteUploadUrl(m.fileUrl || m.fileName);
        if (url && m.media_type !== 'video') items.push({ url, adId: ad._id });
      });
      (ad.gallery || []).forEach(g => {
        const url = toAbsoluteUploadUrl(g.link || g.fileUrl || g.url);
        if (url) items.push({ url, adId: ad._id });
      });
      return items;
    });
  }, [ads]);

  // Check follow status using the proper follow service
  useEffect(() => {
    if (!profile || !userObject) return;
    const userId = profile.user_id?._id || profile.user_id?.id || profile._id;
    if (!userId) return;
    checkFollowStatus(userId)
      .then(status => {
        if (status?.isFollowing || status?.status === 'following') {
          setFollowState('following');
        } else if (status?.isPending || status?.requestPending || status?.requested || status?.status === 'pending') {
          setFollowState('requested');
        } else {
          setFollowState('not_following');
        }
      })
      .catch(() => setFollowState('not_following'));
  }, [profile, userObject]);

  // Listen for follow status changes from other pages
  useEffect(() => {
    if (!profile) return;
    const userId = profile.user_id?._id || profile.user_id?.id || profile._id;
    if (!userId) return;
    const handler = (e) => {
      if (String(e.detail?.userId) === String(userId)) {
        setFollowState(e.detail.state || 'not_following');
      }
    };
    window.addEventListener(FOLLOW_STATUS_CHANGED_EVENT, handler);
    return () => window.removeEventListener(FOLLOW_STATUS_CHANGED_EVENT, handler);
  }, [profile]);

  const toggleFollow = async () => {
    if (!userObject || followLoading) return;
    const userId = profile.user_id?._id || profile.user_id?.id || profile._id;
    if (!userId) return;
    const prevState = followState;
    setFollowLoading(true);
    setFollowState(followed ? 'not_following' : 'following');
    try {
      if (followed) {
        await unfollowUser(userId);
      } else {
        await followUser(userId);
      }
    } catch {
      setFollowState(prevState);
    } finally {
      setFollowLoading(false);
    }
  };

  if (loading) return (
    <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
      <div className="w-10 h-10 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );

  if (error || !profile) return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-4 p-6">
      <div className="w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-2">
        <Building2 size={28} className="text-gray-300 dark:text-gray-600" />
      </div>
      <p className="text-gray-500 dark:text-gray-400 text-center">{error || 'Profile not found.'}</p>
      <button onClick={() => navigate(-1)} className="text-pink-600 font-bold text-sm hover:underline">Go Back</button>
    </div>
  );

  const coverImages    = (profile.cover_image_urls || []).map(toAbsoluteUploadUrl).filter(Boolean);
  const avatarUrl      = toAbsoluteUploadUrl(profile.user_id?.avatar_url || '');
  const businessName   = profile.business_name || profile.company_details?.company_name || profile.user_id?.full_name || 'Vendor';
  const isVerified     = profile.validated === true;
  const followerCount  = profile.follower_count || 0;
  const followingCount = profile.following_count || 0;
  const adCount        = profile.ad_count || 0;
  const op             = profile.online_presence || {};
  const sm             = profile.social_media_links || {};

  const renderAbout = () => (
    <div className="space-y-3 px-4 py-4 max-w-2xl mx-auto lg:px-0">
      {profile.company_description && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 border border-gray-100 dark:border-gray-800 shadow-sm">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-7 h-7 rounded-lg bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center">
              <Info size={14} className="text-blue-500" />
            </div>
            <p className="text-sm font-bold text-gray-900 dark:text-white">About</p>
          </div>
          <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{profile.company_description}</p>
        </div>
      )}

      {/* Company + Business details side by side on larger screens */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
        {profile.company_details && (
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-7 h-7 rounded-lg bg-purple-50 dark:bg-purple-900/20 flex items-center justify-center">
                <Building2 size={14} className="text-purple-500" />
              </div>
              <p className="text-sm font-bold text-gray-900 dark:text-white">Company Details</p>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {[
                { label: 'Company',   value: profile.company_details.company_name },
                { label: 'Industry',  value: profile.company_details.industry },
                { label: 'Type',      value: profile.company_details.company_type },
                { label: 'Est. Year', value: profile.company_details.year_established },
                { label: 'Reg. No',   value: profile.company_details.registration_number },
                { label: 'Tax ID',    value: profile.company_details.tax_id },
              ].filter(i => i.value).map((item, idx) => (
                <div key={idx} className="flex flex-col gap-0.5 p-2.5 rounded-lg bg-gray-50 dark:bg-gray-800/50">
                  <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{item.label}</span>
                  <span className="text-xs font-semibold text-gray-800 dark:text-gray-100">{item.value}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {profile.business_details && (
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-4 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-7 h-7 rounded-lg bg-amber-50 dark:bg-amber-900/20 flex items-center justify-center">
                <Tag size={14} className="text-amber-500" />
              </div>
              <p className="text-sm font-bold text-gray-900 dark:text-white">Business Details</p>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {[
                { label: 'Category', value: profile.business_details.industry_category },
                { label: 'Nature',   value: profile.business_details.business_nature },
                { label: 'Coverage', value: profile.business_details.service_coverage },
                { label: 'Country',  value: profile.business_details.country },
              ].filter(i => i.value).map((item, idx) => (
                <div key={idx} className="flex flex-col gap-0.5 p-2.5 rounded-lg bg-gray-50 dark:bg-gray-800/50">
                  <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{item.label}</span>
                  <span className="text-xs font-semibold text-gray-800 dark:text-gray-100">{item.value}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );

  const renderProducts = () => (
    <div className="px-4 py-6 max-w-2xl mx-auto lg:px-0">
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        {[...Array(6)].map((_, i) => (
          <div key={i} className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden shadow-sm">
            <div className="w-full aspect-square bg-gradient-to-br from-orange-50 to-pink-50 dark:from-orange-900/20 dark:to-pink-900/20 flex items-center justify-center">
              <Package size={28} className="text-orange-200 dark:text-orange-700" />
            </div>
            <div className="p-3 space-y-2">
              <div className="h-2.5 bg-gray-100 dark:bg-gray-800 rounded-full w-3/4 animate-pulse" />
              <div className="h-2 bg-gray-100 dark:bg-gray-800 rounded-full w-1/2 animate-pulse" />
              <div className="h-4 bg-gray-100 dark:bg-gray-800 rounded-full w-1/3 animate-pulse" />
            </div>
          </div>
        ))}
      </div>
      <div className="text-center mt-8">
        <div className="inline-flex items-center gap-2 px-4 py-2 bg-orange-50 dark:bg-orange-900/20 rounded-full">
          <Package size={14} className="text-orange-400" />
          <span className="text-xs font-semibold text-orange-600 dark:text-orange-400">Products coming soon</span>
        </div>
      </div>
    </div>
  );

  const renderGallery = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0">
      {adsLoading ? (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {[...Array(9)].map((_, i) => (
            <div key={i} className="rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '1/1' }} />
          ))}
        </div>
      ) : galleryItems.length === 0 ? (
        <div className="text-center py-20">
          <div className="w-16 h-16 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center mx-auto mb-4">
            <ImageIcon size={28} className="text-gray-300 dark:text-gray-600" />
          </div>
          <p className="text-sm font-medium text-gray-400">No gallery items yet</p>
          <p className="text-xs text-gray-300 dark:text-gray-600 mt-1">Photos will appear here when the vendor uploads them</p>
        </div>
      ) : (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
          {galleryItems.map((item, idx) => (
            <div
              key={idx}
              onClick={() => item.adId && navigate(`/ads/${item.adId}/details`)}
              className="rounded-xl overflow-hidden bg-gray-100 dark:bg-gray-800 cursor-pointer group shadow-sm hover:shadow-md transition-all duration-300"
              style={{ aspectRatio: '1/1' }}
            >
              <img
                src={item.url}
                alt=""
                className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                onError={e => { e.currentTarget.style.display = 'none'; }}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );

  const renderAds = () => (
    <div className="px-4 py-4 max-w-2xl mx-auto lg:px-0">
      {adsLoading ? (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2.5">
          {[...Array(8)].map((_, i) => (
            <div key={i} className="rounded-2xl bg-gray-100 dark:bg-gray-800 animate-pulse" style={{ aspectRatio: '9/16' }} />
          ))}
        </div>
      ) : ads.length === 0 ? (
        <div className="text-center py-20">
          <div className="w-16 h-16 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center mx-auto mb-4">
            <Film size={28} className="text-gray-300 dark:text-gray-600" />
          </div>
          <p className="text-sm font-medium text-gray-400">No Spotlights yet</p>
          <p className="text-xs text-gray-300 dark:text-gray-600 mt-1">This vendor hasn't posted any Spotlights</p>
        </div>
      ) : (
        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2.5">
          {ads.map(ad => (
            <MiniAdCard key={ad._id} ad={ad} onClick={(id) => navigate(`/ads/${id}/details`)} />
          ))}
        </div>
      )}
    </div>
  );

  const renderEvents = () => (
    <div className="px-4 py-6 max-w-2xl mx-auto lg:px-0 space-y-3">
      {[
        { title: 'Annual Sale Event',  date: 'Coming Soon', desc: 'Exciting deals and offers awaiting you',   gradient: 'from-orange-400 to-pink-500' },
        { title: 'New Product Launch', date: 'TBA',         desc: 'New collection unveiling ceremony',        gradient: 'from-purple-400 to-indigo-500' },
        { title: 'Flash Sale',         date: 'TBA',         desc: 'Limited time offers, huge discounts',      gradient: 'from-green-400 to-teal-500' },
      ].map((ev, i) => (
        <div key={i} className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-200">
          <div className="flex items-stretch">
            <div className={`w-1 bg-gradient-to-b ${ev.gradient} flex-shrink-0`} />
            <div className="p-4 flex items-start gap-3.5 flex-1">
              <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${ev.gradient} flex items-center justify-center flex-shrink-0 shadow-sm`}>
                <CalendarDays size={18} className="text-white" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2">
                  <p className="text-sm font-bold text-gray-900 dark:text-white">{ev.title}</p>
                  <span className="text-[10px] font-bold text-gray-400 bg-gray-100 dark:bg-gray-800 px-2.5 py-1 rounded-full flex-shrink-0">{ev.date}</span>
                </div>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">{ev.desc}</p>
              </div>
            </div>
          </div>
        </div>
      ))}
      <div className="text-center pt-4">
        <div className="inline-flex items-center gap-2 px-4 py-2 bg-purple-50 dark:bg-purple-900/20 rounded-full">
          <Calendar size={14} className="text-purple-400" />
          <span className="text-xs font-semibold text-purple-600 dark:text-purple-400">More events coming soon</span>
        </div>
      </div>
    </div>
  );

  const renderLocations = () => {
    const addr = op.address;
    return (
      <div className="px-4 py-6 max-w-2xl mx-auto lg:px-0 space-y-3">
        {addr && (
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5 shadow-sm">
            <div className="flex items-center gap-2.5 mb-4">
              <div className="w-8 h-8 rounded-lg bg-rose-50 dark:bg-rose-900/20 flex items-center justify-center">
                <MapPin size={14} className="text-rose-500" />
              </div>
              <p className="text-sm font-bold text-gray-900 dark:text-white">Primary Location</p>
            </div>
            <div className="flex items-start gap-3.5 p-4 rounded-xl bg-gray-50 dark:bg-gray-800/50">
              <div className="w-10 h-10 rounded-xl bg-rose-50 dark:bg-rose-900/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                <MapPin size={18} className="text-rose-500" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-800 dark:text-gray-100">
                  {[addr.address_line1, addr.address_line2].filter(Boolean).join(', ')}
                </p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  {[addr.city, addr.state, addr.pincode].filter(Boolean).join(', ')}
                </p>
                {addr.country && <p className="text-xs text-gray-400 mt-0.5">{addr.country}</p>}
              </div>
            </div>
          </div>
        )}

        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden shadow-sm">
          <div className="w-full h-52 bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-700 flex flex-col items-center justify-center gap-3">
            <div className="w-14 h-14 rounded-full bg-white dark:bg-gray-700 shadow-md flex items-center justify-center">
              <MapPin size={24} className="text-rose-400" />
            </div>
            <p className="text-xs text-gray-400 font-semibold">Map view coming soon</p>
          </div>
        </div>
      </div>
    );
  };

  const renderContact = () => (
    <div className="px-4 py-6 max-w-2xl mx-auto lg:px-0 space-y-4">
      <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden shadow-sm">
        <div className="px-6 pt-6 pb-2 flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center">
            <Contact size={14} className="text-blue-500" />
          </div>
          <p className="text-sm font-bold text-gray-900 dark:text-white">Contact Information</p>
        </div>
        <div className="px-3 pb-4 divide-y divide-gray-50 dark:divide-gray-800/50">
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

      {op.phone_number && (
        <a
          href={`https://wa.me/${op.phone_number.replace(/\D/g, '')}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center gap-3 w-full py-4 rounded-2xl bg-gradient-to-r from-green-500 to-emerald-600 text-white font-bold text-sm shadow-lg hover:shadow-xl hover:brightness-105 active:scale-[0.98] transition-all duration-200"
        >
          <MessageSquare size={20} />
          Chat on WhatsApp
        </a>
      )}

      {Object.values(sm).some(Boolean) && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-6 shadow-sm">
          <div className="flex items-center gap-2.5 mb-5">
            <div className="w-8 h-8 rounded-lg bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center">
              <Users size={14} className="text-blue-500" />
            </div>
            <p className="text-sm font-bold text-gray-900 dark:text-white">Social Media</p>
          </div>
          <div className="grid grid-cols-2 gap-2.5">
            {sm.instagram && (
              <a href={sm.instagram} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-3 p-3.5 rounded-xl border border-pink-100 dark:border-pink-900/30 bg-pink-50/80 dark:bg-pink-900/10 hover:bg-pink-100 dark:hover:bg-pink-900/20 transition-all duration-200 group">
                <Instagram size={18} className="text-pink-500 flex-shrink-0 group-hover:scale-110 transition-transform" />
                <span className="text-sm font-bold text-pink-700 dark:text-pink-400">Instagram</span>
              </a>
            )}
            {sm.facebook && (
              <a href={sm.facebook} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-3 p-3.5 rounded-xl border border-blue-100 dark:border-blue-900/30 bg-blue-50/80 dark:bg-blue-900/10 hover:bg-blue-100 dark:hover:bg-blue-900/20 transition-all duration-200 group">
                <Facebook size={18} className="text-blue-600 flex-shrink-0 group-hover:scale-110 transition-transform" />
                <span className="text-sm font-bold text-blue-700 dark:text-blue-400">Facebook</span>
              </a>
            )}
            {sm.linkedin && (
              <a href={sm.linkedin} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-3 p-3.5 rounded-xl border border-indigo-100 dark:border-indigo-900/30 bg-indigo-50/80 dark:bg-indigo-900/10 hover:bg-indigo-100 dark:hover:bg-indigo-900/20 transition-all duration-200 group">
                <Linkedin size={18} className="text-indigo-600 flex-shrink-0 group-hover:scale-110 transition-transform" />
                <span className="text-sm font-bold text-indigo-700 dark:text-indigo-400">LinkedIn</span>
              </a>
            )}
            {sm.twitter && (
              <a href={sm.twitter} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-3 p-3.5 rounded-xl border border-sky-100 dark:border-sky-900/30 bg-sky-50/80 dark:bg-sky-900/10 hover:bg-sky-100 dark:hover:bg-sky-900/20 transition-all duration-200 group">
                <Twitter size={18} className="text-sky-500 flex-shrink-0 group-hover:scale-110 transition-transform" />
                <span className="text-sm font-bold text-sky-700 dark:text-sky-400">X (Twitter)</span>
              </a>
            )}
          </div>
        </div>
      )}
    </div>
  );

  const renderTabContent = () => {
    switch (activeTab) {
      case 'About':     return renderAbout();
      case 'Products':  return renderProducts();
      case 'Gallery':   return renderGallery();
      case 'Ads':       return renderAds();
      case 'Events':    return renderEvents();
      case 'Locations': return renderLocations();
      case 'Contact':   return renderContact();
      default:          return null;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 font-sans">

      {/* Back button — desktop only */}
      <div className="absolute top-0 left-0 right-0 z-50 pointer-events-none hidden sm:block">
        <div className="max-w-[1100px] mx-auto px-4 pt-3 pointer-events-auto">
          <button
            onClick={() => navigate(-1)}
            className="w-9 h-9 rounded-full bg-black/30 backdrop-blur-md flex items-center justify-center text-white hover:bg-black/50 transition-colors shadow-lg"
          >
            <ArrowLeft size={18} />
          </button>
        </div>
      </div>

      {/* Cover + Avatar — avatar sits on the cover image */}
      <div className="relative w-[73%] mx-auto h-[160px] sm:h-[220px] overflow-visible">
        <div className="w-full h-full overflow-hidden">
          {coverImages.length > 0 ? (
            <Swiper
              modules={[Autoplay, Pagination]}
              autoplay={{ delay: 4500, disableOnInteraction: false }}
              pagination={{ clickable: true }}
              loop={coverImages.length > 1}
              className="!w-full !h-full"
              style={{ width: '100%', height: '100%' }}
            >
              {coverImages.map((url, i) => (
                <SwiperSlide key={i} className="!w-full !h-full">
                  <img src={url} alt={`Cover ${i + 1}`} className="block w-full h-full object-cover" />
                </SwiperSlide>
              ))}
            </Swiper>
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600" />
          )}
          <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent pointer-events-none z-[1]" />
        </div>

        {/* Avatar — positioned at bottom of cover, overlapping into profile area */}
        <div className="absolute bottom-0 left-4 sm:left-6 translate-y-1/2 z-10">
          <div className="w-[76px] h-[76px] sm:w-[90px] sm:h-[90px] rounded-full border-[3px] sm:border-4 border-white dark:border-gray-900 overflow-hidden bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center shadow-xl">
            {avatarUrl ? (
              <img src={avatarUrl} alt={businessName} className="w-full h-full object-cover" />
            ) : (
              <span className="text-white font-black text-2xl sm:text-3xl select-none">{businessName[0]}</span>
            )}
          </div>
        </div>
      </div>

      {/* Profile header */}
      <div className="bg-white dark:bg-gray-900 border-b border-gray-100 dark:border-gray-800">
        <div className="px-4 max-w-4xl mx-auto">

          {/* Spacer for avatar overlap + follow button row */}
          <div className="flex items-start justify-between pt-11 sm:pt-14 pb-3">
            <div className="flex-1 min-w-0">
              {/* Name + verified */}
              <div className="flex items-center gap-1.5 mb-0.5">
                <h1 className="text-[15px] sm:text-lg font-extrabold text-gray-900 dark:text-white leading-tight truncate">{businessName}</h1>
                {isVerified && (
                  <span className="w-[18px] h-[18px] sm:w-5 sm:h-5 rounded-full bg-gradient-to-r from-blue-500 to-indigo-500 flex items-center justify-center flex-shrink-0">
                    <BadgeCheck size={11} className="text-white" strokeWidth={3} />
                  </span>
                )}
              </div>

              {/* Username + category */}
              <div className="flex items-center gap-1.5 text-[11px] sm:text-xs text-gray-500 dark:text-gray-400 mb-1.5">
                <AtSign size={11} className="text-gray-400" />
                <span className="font-medium">@{profile.user_id?.username || 'vendor'}</span>
                {profile.business_details?.industry_category && (
                  <>
                    <span className="text-gray-300 dark:text-gray-700">·</span>
                    <span className="flex items-center gap-1">
                      <Tag size={11} />
                      {profile.business_details.industry_category}
                    </span>
                  </>
                )}
              </div>

              {/* Nature — desktop only */}
              {profile.business_details?.business_nature && (
                <div className="hidden sm:flex items-center gap-1.5 mb-1.5">
                  <Building2 size={12} className="text-gray-400" />
                  <span className="text-xs text-gray-500 dark:text-gray-400">{profile.business_details.business_nature}</span>
                </div>
              )}

              {/* Stats */}
              <div className="flex items-center gap-3 sm:gap-4">
                {[
                  { count: followerCount, label: 'followers' },
                  { count: followingCount, label: 'following' },
                  { count: adCount, label: 'spotlights' },
                ].map((stat) => (
                  <div key={stat.label} className="flex items-center gap-1">
                    <span className="text-xs sm:text-sm font-extrabold text-gray-900 dark:text-white tabular-nums">{fmt(stat.count)}</span>
                    <span className="text-[10px] sm:text-[11px] text-gray-500 dark:text-gray-400 font-medium">{stat.label}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Follow button */}
            <button
              onClick={toggleFollow}
              disabled={followLoading}
              className={`flex items-center gap-1.5 px-4 sm:px-5 py-1.5 sm:py-2 rounded-lg font-bold text-[11px] sm:text-xs transition-all duration-200 active:scale-[0.96] flex-shrink-0 ml-3 ${
                followed
                  ? 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700 hover:bg-red-50 hover:text-red-500 hover:border-red-200 dark:hover:bg-red-900/20 dark:hover:text-red-400 dark:hover:border-red-800'
                  : 'bg-blue-600 hover:bg-blue-700 text-white'
              }`}
            >
              {followed ? <UserCheck size={13} /> : <UserPlus size={13} />}
              {followed ? 'Following' : 'Follow'}
            </button>
          </div>
        </div>

        {/* Tabs — horizontal scroll */}
        <div className="border-t border-gray-100 dark:border-gray-800">
          <div className="overflow-x-auto max-w-4xl mx-auto" style={{ scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' }}>
            <div className="flex px-2 sm:px-4">
              {TABS.map((tab) => {
                const IconComponent = tab.icon;
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`flex items-center gap-1 sm:gap-1.5 px-3 sm:px-4 py-3 text-[11px] sm:text-xs font-bold whitespace-nowrap border-b-2 transition-all duration-200 ${
                      isActive
                        ? 'border-blue-600 text-blue-600 dark:text-blue-400 dark:border-blue-400'
                        : 'border-transparent text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'
                    }`}
                  >
                    <IconComponent size={13} className={isActive ? '' : 'opacity-70'} />
                    {tab.label}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {/* Tab content */}
      <div className="max-w-4xl mx-auto pb-10">
        {renderTabContent()}
      </div>

    </div>
  );
}
