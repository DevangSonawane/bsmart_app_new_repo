import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Swiper, SwiperSlide } from "swiper/react";
import { Autoplay, Pagination } from "swiper/modules";
import api from "../lib/api";

import "swiper/css";
import "swiper/css/pagination";

import {
  ArrowLeft, Globe, Mail, Phone, MapPin, Instagram,
  Facebook, Linkedin, Twitter, Building2, Calendar,
  Tag, Briefcase, Info, Megaphone, UserCheck,
  Image as ImageIcon, AlertCircle, Heart, MessageCircle,
  Eye, Play, BadgeCheck, ShieldCheck, X, ExternalLink,
} from "lucide-react";

const BASE_URL = "https://api.bebsmart.in";

// ─── Media helpers ────────────────────────────────────────────────────────────
const mediaUrl = (ad) => {
  const m = ad?.media?.[0];
  if (!m) return null;
  if (m.fileUrl?.startsWith("http")) return m.fileUrl;
  if (m.fileName) return `${BASE_URL}/uploads/${m.fileName}`;
  return null;
};
const thumbnailUrl = (ad) => {
  const m = ad?.media?.[0];
  if (!m) return null;
  if (m.thumbnails?.[0]?.fileUrl) return m.thumbnails[0].fileUrl;
  if (m.thumbnail_url) return m.thumbnail_url;
  if (m.media_type !== "video" && m.fileUrl) return m.fileUrl;
  return null;
};
const isVideoAd = (ad) => ad?.media?.[0]?.media_type === "video";

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M";
  if (n >= 1_000) return (n / 1_000).toFixed(1) + "k";
  return String(n);
};

// ─── Instagram blue verified badge ───────────────────────────────────────────
const VerifiedBadge = ({ size = "md" }) => {
  const dim = size === "sm" ? 16 : 20;
  const ico = size === "sm" ? 9 : 12;
  return (
    <span
      title="Verified"
      className="inline-flex items-center justify-center rounded-full bg-[#0095f6] flex-shrink-0"
      style={{ width: dim, height: dim, boxShadow: "0 0 0 2px #fff, 0 0 0 3px #0095f620" }}
    >
      <BadgeCheck size={ico} className="text-white" strokeWidth={3} />
    </span>
  );
};

// ─── Avatar Lightbox ──────────────────────────────────────────────────────────
const AvatarLightbox = ({ src, name, onClose }) => (
  <div
    className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-md p-4"
    onClick={onClose}
  >
    <button
      onClick={onClose}
      className="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-all"
    >
      <X size={20} />
    </button>
    <div
      className="relative max-w-sm w-full"
      onClick={(e) => e.stopPropagation()}
    >
      <div className="rounded-3xl overflow-hidden shadow-2xl">
        {src ? (
          <img src={src} alt={name} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full aspect-square bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center">
            <span className="text-white font-black text-7xl">{name?.[0]?.toUpperCase()}</span>
          </div>
        )}
      </div>
      <p className="text-center text-white/80 text-sm font-semibold mt-3">{name}</p>
    </div>
  </div>
);

// ─── Social Button ────────────────────────────────────────────────────────────
const SocialBtn = ({ href, icon: Icon, colorCls, label }) => {
  if (!href) return null;
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl border text-xs font-bold transition-all hover:scale-105 active:scale-95 shadow-sm ${colorCls}`}
    >
      <Icon size={14} />{label}
    </a>
  );
};

// ─── Tabs config ──────────────────────────────────────────────────────────────
const TABS = [
  { id: "information", label: "Information", mobileLabel: "Info",    icon: Info },
  { id: "ads",         label: "Ads",         mobileLabel: "Ads",     icon: Megaphone },
  { id: "contact",     label: "Contact",     mobileLabel: "Contact", icon: UserCheck },
];

// ─── Ad Card ─────────────────────────────────────────────────────────────────
const AdCard = ({ ad }) => {
  const videoRef  = useRef(null);
  const [hovered, setHovered] = useState(false);

  const thumb  = thumbnailUrl(ad);
  const src    = mediaUrl(ad);
  const hasVid = isVideoAd(ad);
  const likes    = ad.likes_count    ?? ad.likes    ?? 0;
  const comments = ad.comments_count ?? ad.comments ?? 0;
  const views    = ad.views_count    ?? ad.views    ?? 0;
  const category = ad.category || ad.ad_type || null;

  const onEnter = () => {
    setHovered(true);
    if (hasVid && videoRef.current) {
      videoRef.current.currentTime = 0;
      videoRef.current.play().catch(() => {});
    }
  };
  const onLeave = () => {
    setHovered(false);
    if (hasVid && videoRef.current) {
      videoRef.current.pause();
      videoRef.current.currentTime = 0;
    }
  };

  return (
    <div
      onMouseEnter={onEnter}
      onMouseLeave={onLeave}
      className="relative overflow-hidden rounded-2xl bg-gray-100 dark:bg-gray-800 cursor-pointer group"
      style={{ aspectRatio: "1/1" }}
    >
      {/* Background thumbnail — always covers the card */}
      {thumb ? (
        <img
          src={thumb}
          alt={ad.ad_title || "Ad"}
          className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
        />
      ) : (
        <div className="absolute inset-0 bg-gradient-to-br from-orange-100 to-pink-100 dark:from-orange-900/30 dark:to-pink-900/30" />
      )}

      {/* Silent video on hover */}
      {hasVid && src && (
        <video
          ref={videoRef}
          src={src}
          muted
          loop
          playsInline
          className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-300 ${hovered ? "opacity-100" : "opacity-0"}`}
        />
      )}

      {/* Always-visible dark gradient + category label at bottom */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent z-10" />

      {/* Category name overlay */}
      <div className="absolute bottom-0 left-0 right-0 z-20 px-2.5 pb-2.5">
        {category && (
          <span className="block text-[11px] font-black uppercase tracking-widest text-white/90 truncate">
            {category}
          </span>
        )}
        {(ad.ad_title || ad.caption) && (
          <span className="block text-[10px] text-white/60 truncate leading-tight">
            {ad.ad_title || ad.caption}
          </span>
        )}
      </div>

      {/* Video play badge (top-right) */}
      {hasVid && (
        <div className="absolute top-2 right-2 z-20 w-6 h-6 rounded-full bg-black/60 flex items-center justify-center">
          <Play size={9} className="text-white fill-white ml-0.5" />
        </div>
      )}

      {/* Hover overlay — engagement stats */}
      <div className={`absolute inset-0 bg-black/50 z-30 flex flex-col items-center justify-center gap-3 transition-opacity duration-200 ${hovered ? "opacity-100" : "opacity-0"}`}>
        <div className="flex items-center gap-4">
          <span className="flex items-center gap-1 text-white text-sm font-black">
            <Heart size={14} className="fill-white" /> {fmt(likes)}
          </span>
          <span className="flex items-center gap-1 text-white text-sm font-black">
            <MessageCircle size={14} className="fill-white" /> {fmt(comments)}
          </span>
          {views > 0 && (
            <span className="flex items-center gap-1 text-white text-sm font-black">
              <Eye size={14} /> {fmt(views)}
            </span>
          )}
        </div>
      </div>
    </div>
  );
};


// ─── Ads Tab ──────────────────────────────────────────────────────────────────
const AdsTab = ({ userId }) => {
  const [ads, setAds]         = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState("");

  useEffect(() => {
    if (!userId) return;
    setLoading(true);
    api.get(`/ads/user/${userId}`)
      .then((res) => {
        const raw = res.data?.ads || res.data || [];
        setAds(Array.isArray(raw) ? raw : []);
      })
      .catch(() => setError("Could not load ads."))
      .finally(() => setLoading(false));
  }, [userId]);

  if (loading) return (
    <div className="flex flex-col items-center justify-center py-20 gap-3">
      <div className="w-8 h-8 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
      <span className="text-sm text-gray-400">Loading ads…</span>
    </div>
  );

  if (error) return (
    <div className="flex items-center gap-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-500 px-4 py-3 rounded-2xl text-sm m-3">
      <AlertCircle size={14} /> {error}
    </div>
  );

  if (ads.length === 0) return (
    <div className="flex flex-col items-center py-20 gap-3 rounded-3xl border-2 border-dashed border-gray-200 dark:border-gray-700 m-3">
      <Megaphone size={36} className="text-gray-300 dark:text-gray-600" />
      <p className="text-sm text-gray-400 font-medium">No ads yet</p>
    </div>
  );

  return (
    <div
      className="grid gap-0.5 p-0.5"
      style={{ gridTemplateColumns: "repeat(3, 1fr)" }}
    >
      {ads.map((ad, i) => (
        <AdCard key={ad._id || i} ad={ad} />
      ))}
    </div>
  );
};

// ─── Info stat chip ───────────────────────────────────────────────────────────
const StatChip = ({ icon: Icon, iconColor, bg, border, label, value }) => (
  <div className={`${bg} ${border} border rounded-2xl p-4 flex flex-col justify-between min-h-[96px]`}>
    <Icon size={18} className={iconColor} />
    <div>
      <div className={`text-[10px] font-black uppercase tracking-widest mb-0.5 ${iconColor}`}>{label}</div>
      <div className="text-sm font-bold text-gray-800 dark:text-gray-100 leading-tight">{value}</div>
    </div>
  </div>
);

// ─── Information Tab ──────────────────────────────────────────────────────────
const InformationTab = ({ data }) => {
  const addr  = data.online_presence?.address;
  const parts = [addr?.address_line1, addr?.address_line2, addr?.city, addr?.state, addr?.pincode, addr?.country].filter(Boolean);
  const addressStr = parts.join(", ");
  const hasSocial  = data.social_media_links?.instagram || data.social_media_links?.facebook
    || data.social_media_links?.linkedin || data.social_media_links?.twitter;
  const industry   = data.company_details?.industry || data.business_details?.industry_category;

  return (
    <div className="space-y-4">

      {/* ── About card (full width) ── */}
      {data.company_description && (
        <div className="bg-gradient-to-br from-orange-50 via-pink-50 to-purple-50 dark:from-orange-950/30 dark:via-pink-950/30 dark:to-purple-950/30 border border-orange-100 dark:border-orange-900/20 rounded-3xl p-5">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-6 h-6 rounded-lg bg-orange-100 dark:bg-orange-900/40 flex items-center justify-center">
              <Building2 size={12} className="text-orange-500" />
            </div>
            <span className="text-[10px] font-black text-orange-500 uppercase tracking-widest">About</span>
          </div>
          <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">{data.company_description}</p>
        </div>
      )}

      {/* ── Stat chips grid ── */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-2.5">
        {industry && (
          <StatChip icon={Tag} iconColor="text-violet-500"
            bg="bg-violet-50 dark:bg-violet-950/30" border="border-violet-100 dark:border-violet-900/20"
            label="Industry" value={industry} />
        )}
        {data.business_details?.business_nature && (
          <StatChip icon={Briefcase} iconColor="text-blue-500"
            bg="bg-blue-50 dark:bg-blue-950/30" border="border-blue-100 dark:border-blue-900/20"
            label="Nature" value={data.business_details.business_nature} />
        )}
        {data.business_details?.service_coverage && (
          <StatChip icon={Globe} iconColor="text-teal-500"
            bg="bg-teal-50 dark:bg-teal-950/30" border="border-teal-100 dark:border-teal-900/20"
            label="Coverage" value={data.business_details.service_coverage} />
        )}
        {data.company_details?.year_established && (
          <div className="bg-amber-50 dark:bg-amber-950/30 border border-amber-100 dark:border-amber-900/20 rounded-2xl p-4 flex flex-col justify-between min-h-[96px]">
            <Calendar size={18} className="text-amber-500" />
            <div>
              <div className="text-[10px] font-black text-amber-500 uppercase tracking-widest mb-0.5">Est.</div>
              <div className="text-2xl font-black text-gray-800 dark:text-gray-100">{data.company_details.year_established}</div>
            </div>
          </div>
        )}
        {data.business_details?.country && (
          <StatChip icon={MapPin} iconColor="text-rose-500"
            bg="bg-rose-50 dark:bg-rose-950/30" border="border-rose-100 dark:border-rose-900/20"
            label="Country" value={data.business_details.country} />
        )}
        {data.company_details?.company_type && (
          <StatChip icon={Building2} iconColor="text-slate-500"
            bg="bg-slate-50 dark:bg-slate-800/60" border="border-slate-100 dark:border-slate-700"
            label="Company Type" value={data.company_details.company_type} />
        )}
      </div>

      {/* ── Registration details ── */}
      {(data.company_details?.registration_number || data.company_details?.tax_id) && (
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl p-5">
          <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-4">Registration</div>
          <div className="flex flex-wrap gap-6">
            {data.company_details?.registration_number && (
              <div>
                <div className="text-[10px] text-gray-400 font-semibold mb-1">Reg. Number</div>
                <div className="text-sm font-bold text-gray-900 dark:text-white font-mono tracking-wide">
                  {data.company_details.registration_number}
                </div>
              </div>
            )}
            {data.company_details?.tax_id && (
              <div>
                <div className="text-[10px] text-gray-400 font-semibold mb-1">Tax ID / GST</div>
                <div className="text-sm font-bold text-gray-900 dark:text-white font-mono tracking-wide">
                  {data.company_details.tax_id}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Address ── */}
      {addressStr && (
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl p-5">
          <div className="flex items-start gap-3">
            <div className="w-9 h-9 rounded-xl bg-rose-50 dark:bg-rose-900/30 flex items-center justify-center flex-shrink-0">
              <MapPin size={16} className="text-rose-500" />
            </div>
            <div>
              <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Address</div>
              <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">{addressStr}</p>
            </div>
          </div>
        </div>
      )}

      {/* ── Social Media ── */}
      {hasSocial && (
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl p-5">
          <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-4">Social Media</div>
          <div className="flex flex-wrap gap-2">
            <SocialBtn href={data.social_media_links?.instagram} icon={Instagram} label="Instagram"
              colorCls="border-pink-200 dark:border-pink-900 text-pink-600 dark:text-pink-400 bg-pink-50 dark:bg-pink-900/20 hover:bg-pink-100 dark:hover:bg-pink-900/30" />
            <SocialBtn href={data.social_media_links?.facebook} icon={Facebook} label="Facebook"
              colorCls="border-blue-200 dark:border-blue-900 text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100 dark:hover:bg-blue-900/30" />
            <SocialBtn href={data.social_media_links?.linkedin} icon={Linkedin} label="LinkedIn"
              colorCls="border-blue-300 dark:border-blue-800 text-blue-700 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100 dark:hover:bg-blue-900/30" />
            <SocialBtn href={data.social_media_links?.twitter} icon={Twitter} label="Twitter"
              colorCls="border-sky-200 dark:border-sky-900 text-sky-500 dark:text-sky-400 bg-sky-50 dark:bg-sky-900/20 hover:bg-sky-100 dark:hover:bg-sky-900/30" />
          </div>
        </div>
      )}
    </div>
  );
};

// ─── Contact Tab ──────────────────────────────────────────────────────────────
const ContactTab = ({ data }) => {
  const items = [
    data.online_presence?.company_email && {
      icon: Mail, iconBg: "bg-pink-50 dark:bg-pink-900/30", iconColor: "text-pink-500",
      label: "Company Email", value: data.online_presence.company_email,
      href: `mailto:${data.online_presence.company_email}`,
    },
    data.online_presence?.phone_number && {
      icon: Phone, iconBg: "bg-green-50 dark:bg-green-900/30", iconColor: "text-green-500",
      label: "Phone Number", value: data.online_presence.phone_number,
      href: `tel:${data.online_presence.phone_number}`,
    },
    data.online_presence?.website_url && {
      icon: Globe, iconBg: "bg-blue-50 dark:bg-blue-900/30", iconColor: "text-blue-500",
      label: "Website", value: data.online_presence.website_url,
      href: data.online_presence.website_url,
    },
    data.user_id?.email && {
      icon: Mail, iconBg: "bg-orange-50 dark:bg-orange-900/30", iconColor: "text-orange-500",
      label: "Account Email", value: data.user_id.email,
      href: `mailto:${data.user_id.email}`,
    },
  ].filter(Boolean);

  return (
    <div className="space-y-3">
      {items.length === 0 ? (
        <div className="text-center py-12 text-gray-400 text-sm">No contact info available.</div>
      ) : (
        items.map((item, i) => (
          <a
            key={i}
            href={item.href}
            target={item.href.startsWith("http") ? "_blank" : "_self"}
            rel="noopener noreferrer"
            className="flex items-center gap-4 p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl hover:border-gray-200 dark:hover:border-gray-700 hover:shadow-sm transition-all group"
          >
            <div className={`w-10 h-10 rounded-2xl ${item.iconBg} flex items-center justify-center flex-shrink-0`}>
              <item.icon size={16} className={item.iconColor} />
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{item.label}</div>
              <div className={`text-sm font-semibold mt-0.5 truncate ${item.iconColor} group-hover:underline`}>{item.value}</div>
            </div>
            <ExternalLink size={13} className="text-gray-300 group-hover:text-gray-400 flex-shrink-0 transition-colors" />
          </a>
        ))
      )}

      {(data.online_presence?.company_email || data.online_presence?.phone_number) && (
        <div className="flex gap-3 pt-2">
          {data.online_presence?.company_email && (
            <a
              href={`mailto:${data.online_presence.company_email}`}
              className="flex-1 flex items-center justify-center gap-2 py-4 rounded-2xl bg-gradient-to-r from-orange-500 to-pink-600 text-white text-sm font-bold shadow-lg shadow-pink-500/25 hover:opacity-90 transition-all active:scale-[0.98]"
            >
              <Mail size={15} /> Send Email
            </a>
          )}
          {data.online_presence?.phone_number && (
            <a
              href={`tel:${data.online_presence.phone_number}`}
              className="flex-1 flex items-center justify-center gap-2 py-4 rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-200 text-sm font-bold hover:bg-gray-50 dark:hover:bg-gray-800 transition-all active:scale-[0.98]"
            >
              <Phone size={15} /> Call Now
            </a>
          )}
        </div>
      )}
    </div>
  );
};

// ─── Root Component ───────────────────────────────────────────────────────────
export default function VendorPublicProfile() {
  const { userId }              = useParams();
  const navigate                = useNavigate();
  const [data, setData]         = useState(null);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState("");
  const [activeTab, setActiveTab]     = useState("information");
  const [avatarOpen, setAvatarOpen]   = useState(false);

  useEffect(() => {
    if (!userId) return;
    setLoading(true);
    setError("");
    api.get(`/vendors/profile/${userId}/public`)
      .then((res) => setData(res.data))
      .catch(() => setError("Failed to load vendor profile. Please try again."))
      .finally(() => setLoading(false));
  }, [userId]);

  if (loading) return (
    <div className="min-h-screen bg-gray-50 dark:bg-black flex flex-col items-center justify-center gap-4">
      <div className="w-10 h-10 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
      <span className="text-sm text-gray-400">Loading profile…</span>
    </div>
  );

  if (error) return (
    <div className="min-h-screen bg-gray-50 dark:bg-black flex flex-col items-center justify-center gap-4 p-6">
      <AlertCircle size={40} className="text-red-400" />
      <p className="text-base font-semibold text-gray-700 dark:text-gray-300">{error}</p>
      <button onClick={() => navigate(-1)} className="text-sm text-pink-600 font-bold hover:underline">← Go Back</button>
    </div>
  );

  if (!data) return null;

  const companyName  = data.company_details?.company_name || data.business_name || "Vendor";
  const isVerified   = data.validated === true;
  const avatarSrc    = data.avatar_url || data.user_id?.avatar_url;
  const coverUrls    = data.cover_image_urls || [];
  const industry     = data.company_details?.industry || data.business_details?.industry_category;
  const vendorUserId = data.user_id?._id || (typeof data.user_id === "string" ? data.user_id : null) || userId;

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans">

      {/* ── Avatar Lightbox ── */}
      {avatarOpen && (
        <AvatarLightbox src={avatarSrc} name={companyName} onClose={() => setAvatarOpen(false)} />
      )}

      {/* ── Cover image ── */}
      <div className="relative">
        <button
          onClick={() => navigate(-1)}
          className="absolute top-4 left-4 z-30 flex items-center gap-1.5 px-3 py-2 rounded-xl bg-black/40 backdrop-blur-sm text-white text-xs font-bold hover:bg-black/60 transition-all shadow-lg"
        >
          <ArrowLeft size={14} /> Back
        </button>

        <div className="h-52 md:h-72 bg-gray-200 dark:bg-gray-800 overflow-hidden">
          {coverUrls.length > 0 ? (
            <Swiper
              modules={[Autoplay, Pagination]}
              autoplay={{ delay: 3500, disableOnInteraction: false }}
              pagination={{ clickable: true }}
              className="w-full h-full"
            >
              {coverUrls.map((url, i) => (
                <SwiperSlide key={i}>
                  <img src={url} alt={`Cover ${i + 1}`} className="w-full h-full object-cover" />
                </SwiperSlide>
              ))}
            </Swiper>
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600 relative overflow-hidden">
              <div
                className="absolute inset-0 opacity-10"
                style={{ backgroundImage: "radial-gradient(circle, white 1px, transparent 1px)", backgroundSize: "24px 24px" }}
              />
              <div className="absolute inset-0 flex items-center justify-center">
                <ImageIcon size={56} className="text-white/20" />
              </div>
            </div>
          )}
        </div>

        {/* ── Profile identity row ── */}
        <div className="max-w-3xl mx-auto px-4">
          <div className="flex items-end justify-between relative z-10" style={{ marginTop: "-44px" }}>

            {/* Clickable Avatar */}
            <button
              onClick={() => setAvatarOpen(true)}
              className="w-[88px] h-[88px] md:w-[96px] md:h-[96px] rounded-2xl overflow-hidden bg-white dark:bg-gray-800 border-4 border-white dark:border-gray-900 shadow-xl flex-shrink-0 cursor-pointer hover:scale-105 transition-transform duration-200 active:scale-95 focus:outline-none"
              title="View profile photo"
            >
              {avatarSrc ? (
                <img src={avatarSrc} alt={companyName} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center">
                  <span className="text-white font-black text-3xl">{companyName[0]?.toUpperCase()}</span>
                </div>
              )}
            </button>

            {/* Visit Website CTA */}
            {data.online_presence?.website_url && (
              <a
                href={data.online_presence.website_url}
                target="_blank"
                rel="noopener noreferrer"
                className="mb-1 flex items-center gap-1.5 px-4 py-2.5 rounded-2xl text-xs font-bold bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-lg shadow-pink-500/30 hover:opacity-90 hover:shadow-pink-500/40 transition-all"
              >
                <Globe size={12} /> Visit Website
              </a>
            )}
          </div>

          {/* Name + verified + meta */}
          <div className="mt-3 pb-5">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-xl md:text-2xl font-extrabold text-gray-900 dark:text-white tracking-tight">
                {companyName}
              </h1>
              {isVerified && <VerifiedBadge />}
            </div>

            <div className="flex flex-wrap items-center gap-1.5 mt-2">
              {industry && (
                <span className="flex items-center gap-1 text-[11px] font-semibold text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 px-2.5 py-1 rounded-full shadow-sm">
                  <Tag size={9} /> {industry}
                </span>
              )}
              {data.business_details?.service_coverage && (
                <span className="flex items-center gap-1 text-[11px] font-semibold text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 px-2.5 py-1 rounded-full shadow-sm">
                  <MapPin size={9} /> {data.business_details.service_coverage}
                </span>
              )}
              {data.business_details?.country && (
                <span className="text-[11px] font-semibold text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 px-2.5 py-1 rounded-full shadow-sm">
                  🌏 {data.business_details.country}
                </span>
              )}
              {isVerified && (
                <span className="flex items-center gap-1 text-[11px] font-semibold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/20 px-2.5 py-1 rounded-full border border-emerald-100 dark:border-emerald-900/30">
                  <ShieldCheck size={9} /> Verified Business
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* ── Tabs ── */}
      <div className="sticky top-0 z-20 bg-white/95 dark:bg-black/95 backdrop-blur-md border-b border-gray-100 dark:border-gray-800">
        <div className="max-w-3xl mx-auto px-4">
          <div className="flex">
            {TABS.map((t) => {
              const Icon   = t.icon;
              const active = activeTab === t.id;
              return (
                <button
                  key={t.id}
                  onClick={() => setActiveTab(t.id)}
                  className={`flex-1 flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-1.5 py-3.5 text-[11px] sm:text-xs font-bold transition-all border-b-2 ${
                    active
                      ? "border-pink-500 text-pink-600 dark:text-pink-400"
                      : "border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                  }`}
                >
                  <Icon size={15} />
                  <span className="hidden sm:inline">{t.label}</span>
                  <span className="sm:hidden">{t.mobileLabel}</span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* ── Tab content ── */}
      <div className={`max-w-3xl mx-auto pb-24 ${activeTab === "ads" ? "pt-1" : "px-4 py-5"}`}>
        {activeTab === "information" && <InformationTab data={data} />}
        {activeTab === "ads"         && <AdsTab userId={vendorUserId} />}
        {activeTab === "contact"     && <ContactTab data={data} />}
      </div>
    </div>
  );
}