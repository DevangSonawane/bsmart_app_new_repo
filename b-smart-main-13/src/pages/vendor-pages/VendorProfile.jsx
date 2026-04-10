import { useState, useRef, useEffect } from "react";
import { useSelector } from "react-redux";
import api from "../../lib/api";
import AvatarCropModal from "../../components/AvatarCropModal";
import CoverImageCropModal from "../../components/CoverImageCropModal";
import { Swiper, SwiperSlide } from "swiper/react";
import { Autoplay, Pagination } from "swiper/modules";

// Swiper styles
import "swiper/css";
import "swiper/css/pagination";

import {
  Building2, User, Handshake, ChevronDown, ChevronUp,
  Globe, Mail, Phone, MapPin, Edit3, Check, X,
  Loader2, AlertCircle, CheckCircle2, Instagram,
  Facebook, Linkedin, Twitter, Plus, Trash2, Save,
  Shield, Star, BadgeCheck, Camera, Image as ImageIcon,
  GripVertical,
} from "lucide-react";

// Cover Manager Modal
const CoverManagerModal = ({ images, onClose, onAdd, onDelete, onReorder, deleting }) => {
  const [localImages, setLocalImages] = useState([...images]);
  const dragIdx = useRef(null);
  const handleDragStart = (i) => { dragIdx.current = i; };
  const handleDragOver  = (e, i) => {
    e.preventDefault();
    if (dragIdx.current === null || dragIdx.current === i) return;
    const arr = [...localImages];
    const [moved] = arr.splice(dragIdx.current, 1);
    arr.splice(i, 0, moved);
    dragIdx.current = i;
    setLocalImages(arr);
  };
  const handleDrop = () => { onReorder(localImages); dragIdx.current = null; };
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="w-full sm:max-w-md rounded-t-3xl sm:rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl overflow-hidden">
        <div className="sm:hidden flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-gray-200 dark:bg-gray-700" /></div>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
          <div>
            <div className="text-base font-black text-gray-900 dark:text-white">Manage Cover Photos</div>
            <div className="text-xs text-gray-400 mt-0.5">Drag to reorder · tap ✕ to remove</div>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-gray-400"><X size={16} /></button>
        </div>
        <div className="p-4 space-y-2 max-h-[50vh] overflow-y-auto">
          {localImages.length === 0 && (<div className="text-center py-10 text-gray-400 text-sm">No cover photos yet.</div>)}
          {localImages.map((url, i) => (
            <div key={url} draggable onDragStart={() => handleDragStart(i)} onDragOver={(e) => handleDragOver(e, i)} onDrop={handleDrop}
              className="flex items-center gap-3 p-2 rounded-2xl border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50 cursor-grab active:cursor-grabbing hover:border-gray-200 dark:hover:border-gray-700 transition-all">
              <GripVertical size={16} className="text-gray-300 dark:text-gray-600 flex-shrink-0" />
              <img src={url} alt={`Cover ${i+1}`} className="w-14 h-10 object-cover rounded-lg flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="text-xs font-semibold text-gray-700 dark:text-gray-300">
                  {i === 0 ? <span className="text-pink-600 dark:text-pink-400 font-bold">First (shown first)</span> : `Photo ${i + 1}`}
                </div>
                <div className="text-[10px] text-gray-400">Drag to reorder</div>
              </div>
              <button onClick={() => onDelete(url)} disabled={deleting === url}
                className="w-7 h-7 rounded-xl bg-red-50 dark:bg-red-900/20 text-red-500 flex items-center justify-center hover:bg-red-100 transition-colors disabled:opacity-50 flex-shrink-0">
                {deleting === url ? <Loader2 size={12} className="animate-spin" /> : <Trash2 size={12} />}
              </button>
            </div>
          ))}
        </div>
        <div className="px-4 pb-4 pt-2 border-t border-gray-100 dark:border-gray-800">
          <button onClick={onAdd} className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl border-2 border-dashed border-pink-200 dark:border-pink-900 text-pink-600 dark:text-pink-400 text-sm font-bold hover:bg-pink-50 dark:hover:bg-pink-900/10 transition-colors">
            <Plus size={16} /> Add Cover Photo
          </button>
        </div>
      </div>
    </div>
  );
};

// Avatar Manager Modal
const AvatarManagerModal = ({ avatarUrl, companyName, onClose, onUpload, onDelete, deleting }) => (
  <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={e => e.target === e.currentTarget && onClose()}>
    <div className="w-full sm:max-w-xs rounded-t-3xl sm:rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl overflow-hidden">
      <div className="sm:hidden flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-gray-200 dark:bg-gray-700" /></div>
      <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
        <div className="text-base font-black text-gray-900 dark:text-white">Profile Photo</div>
        <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-400"><X size={16} /></button>
      </div>
      <div className="flex flex-col items-center gap-4 px-5 py-6">
        <div className="w-24 h-24 rounded-2xl overflow-hidden bg-gray-100 dark:bg-gray-800 border-4 border-white dark:border-gray-900 shadow-xl">
          {avatarUrl
            ? <img src={avatarUrl} alt="Logo" className="w-full h-full object-cover" />
            : <div className="w-full h-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-3xl font-black text-white">{companyName?.[0]?.toUpperCase() || "?"}</div>
          }
        </div>
        <div className="text-sm font-semibold text-gray-700 dark:text-gray-300">{companyName || "Logo"}</div>
      </div>
      <div className="px-4 pb-5 space-y-2">
        <button onClick={onUpload} className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl bg-gradient-to-r from-orange-500 to-pink-600 text-white text-sm font-bold hover:opacity-90 transition-all shadow-md shadow-pink-500/20">
          <Camera size={15} /> {avatarUrl ? "Change Photo" : "Upload Photo"}
        </button>
        {avatarUrl && (
          <button onClick={onDelete} disabled={deleting} className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl border border-red-200 dark:border-red-800 text-red-500 text-sm font-bold hover:bg-red-50 dark:hover:bg-red-900/20 transition-all disabled:opacity-50">
            {deleting ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
            {deleting ? "Removing…" : "Remove Photo"}
          </button>
        )}
        <button onClick={onClose} className="w-full py-2 text-xs text-gray-400 hover:text-gray-600 transition-colors">Cancel</button>
      </div>
    </div>
  </div>
);

// ─── Reusable Field Components ───────────────────────────────────────────────
const Field = ({ label, children, required }) => (
  <div>
    <label className="block text-[10px] font-bold mb-1 tracking-widest uppercase text-gray-400 dark:text-gray-500">
      {label}{required && <span className="text-pink-500 ml-0.5">*</span>}
    </label>
    {children}
  </div>
);

const inputCls = `w-full px-3.5 py-2.5 rounded-xl text-sm transition-all outline-none
  bg-gray-50 dark:bg-gray-900
  border border-gray-200 dark:border-gray-800
  text-gray-900 dark:text-white
  placeholder:text-gray-400 dark:placeholder:text-gray-600
  focus:ring-2 focus:ring-pink-500/20 focus:border-pink-500
  disabled:opacity-50 disabled:cursor-not-allowed`;

const Input = ({ type = "text", placeholder, value, onChange, disabled, icon }) => (
  <div className="relative">
    {icon && <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm opacity-40">{icon}</span>}
    <input type={type} placeholder={placeholder} value={value} onChange={onChange} disabled={disabled}
      className={`${inputCls} ${icon ? 'pl-9' : ''}`} />
  </div>
);

const SelectField = ({ options, value, onChange, disabled, placeholder }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);
  useEffect(() => {
    const h = (e) => { if (!ref.current?.contains(e.target)) setOpen(false); };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);
  const choose = (v) => { onChange({ target: { value: v } }); setOpen(false); };
  return (
    <div className="relative" ref={ref}>
      <button type="button" disabled={disabled} onClick={() => !disabled && setOpen(v => !v)}
        className={`${inputCls} flex items-center justify-between`}>
        <span className={value ? "text-gray-900 dark:text-white" : "text-gray-400 dark:text-gray-600"}>{value || placeholder || "Select"}</span>
        <ChevronDown className={`w-4 h-4 ml-2 transition-transform flex-shrink-0 ${open ? "rotate-180" : ""}`} />
      </button>
      {open && !disabled && (
        <div className="absolute z-30 mt-1 w-full rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-xl overflow-hidden">
          <div className="max-h-48 overflow-auto py-1">
            {placeholder && <div onClick={() => choose("")} className="px-3.5 py-2 text-sm cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 text-gray-400">{placeholder}</div>}
            {options.map(opt => (
              <div key={opt} onClick={() => choose(opt)}
                className={`px-3.5 py-2 text-sm cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 ${opt === value ? "text-pink-600 font-semibold bg-pink-50 dark:bg-pink-900/20" : "text-gray-700 dark:text-gray-300"}`}>
                {opt}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

const Textarea = ({ placeholder, value, onChange, disabled, rows = 4 }) => (
  <textarea placeholder={placeholder} value={value} onChange={onChange} disabled={disabled} rows={rows}
    className={`${inputCls} resize-y`} />
);

// ─── Completion Bar ───────────────────────────────────────────────────────────
const CompletionBar = ({ pct }) => (
  <div className="px-5 py-4 rounded-2xl bg-gray-900 dark:bg-gray-900 border border-gray-800">
    <div className="flex justify-between items-center mb-2">
      <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Profile Completion</span>
      <span className="text-sm font-black bg-clip-text text-transparent bg-gradient-to-r from-orange-400 to-pink-500">{pct}%</span>
    </div>
    <div className="h-2 w-full bg-gray-800 rounded-full overflow-hidden">
      <div className="h-full rounded-full bg-gradient-to-r from-orange-500 to-pink-600 transition-all duration-700"
        style={{ width: `${pct}%` }} />
    </div>
    {pct < 100 && <p className="text-[10px] mt-1.5 text-gray-500">Complete all fields to submit for verification</p>}
  </div>
);

const ValidationStatusBadge = ({ validated, status }) => {
  const label = validated ? "Validated" : (status ? String(status).replaceAll("_", " ") : "Not Validated");
  const classes = validated
    ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400 border-emerald-200 dark:border-emerald-800"
    : "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-200 dark:border-amber-800";

  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-[11px] font-bold uppercase tracking-wide ${classes}`}>
      {validated ? <CheckCircle2 size={12} /> : <AlertCircle size={12} />}
      {label}
    </span>
  );
};

const CompletionReminderModal = ({ pct, onClose, onEdit }) => (
  <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
    <div className="w-full max-w-md rounded-3xl border border-white/10 bg-[#171b2a] p-6 shadow-2xl">
      <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-orange-500/20 to-pink-600/20 text-orange-400">
        <AlertCircle size={26} />
      </div>
      <div className="text-center">
        <h3 className="text-2xl font-black text-white">Complete your vendor profile</h3>
        <p className="mt-3 text-sm leading-6 text-gray-300">
          Your profile is currently <span className="font-bold text-orange-400">{pct}%</span> complete.
          Please finish the remaining details to unlock the full vendor experience.
        </p>
      </div>
      <div className="mt-5 h-2.5 w-full overflow-hidden rounded-full bg-white/10">
        <div
          className="h-full rounded-full bg-gradient-to-r from-orange-500 to-pink-600 transition-all duration-700"
          style={{ width: `${pct}%` }}
        />
      </div>
      <div className="mt-6 flex gap-3">
        <button
          type="button"
          onClick={onClose}
          className="flex-1 rounded-2xl border border-white/10 px-4 py-3 text-sm font-bold text-gray-300 transition hover:bg-white/5"
        >
          Later
        </button>
        <button
          type="button"
          onClick={onEdit}
          className="flex-1 rounded-2xl bg-gradient-to-r from-orange-500 to-pink-600 px-4 py-3 text-sm font-bold text-white shadow-lg shadow-pink-500/20 transition hover:opacity-90"
        >
          Complete Now
        </button>
      </div>
    </div>
  </div>
);

// ─── Section Divider ──────────────────────────────────────────────────────────
const SectionDivider = ({ children }) => (
  <div className="col-span-1 md:col-span-2 flex items-center gap-3 mt-6 mb-2">
    <span className="text-[10px] font-black text-pink-500 uppercase tracking-widest whitespace-nowrap">{children}</span>
    <div className="flex-1 h-px bg-pink-100 dark:bg-pink-900/30" />
  </div>
);

// ─── Collapsible Section ──────────────────────────────────────────────────────
const CollapsibleSection = ({ title, icon: Icon, iconColor = "text-pink-500", children, defaultOpen = false }) => {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 overflow-hidden">
      <button onClick={() => setOpen(v => !v)}
        className="w-full flex items-center justify-between px-4 py-3.5 text-left active:bg-gray-50 dark:active:bg-gray-800 transition-colors">
        <div className="flex items-center gap-2.5">
          <div className={`w-7 h-7 rounded-lg bg-gray-50 dark:bg-gray-800 flex items-center justify-center ${iconColor}`}>
            <Icon size={14} />
          </div>
          <span className="text-sm font-bold text-gray-900 dark:text-white">{title}</span>
        </div>
        {open ? <ChevronUp size={16} className="text-gray-400" /> : <ChevronDown size={16} className="text-gray-400" />}
      </button>
      {open && <div className="px-4 pb-4 space-y-3.5 border-t border-gray-50 dark:border-gray-800 pt-4">{children}</div>}
    </div>
  );
};

// ─── Empty form defaults ──────────────────────────────────────────────────────
const EMPTY_FORM = {
  companyName: "", registeredName: "", regNumber: "", taxId: "",
  yearEstablished: "", companyType: "", userEmail: "", userPhone: "",
  userFullName: "", industry: "", businessNature: "", coverage: "",
  country: "", website: "", email: "", phone: "",
  addressLine1: "", addressLine2: "", city: "", pincode: "",
  state: "", addressCountry: "", instagram: "", facebook: "",
  linkedin: "", twitter: "", description: "", profileCompletion: 0,
  validated: false, verificationStatus: "", coverImageUrls: [],
  avatarUrl: "",
};

const mapApiToForm = (data) => ({
  companyName:      data.company_details?.company_name       ?? "",
  registeredName:   data.company_details?.registered_name    ?? "",
  regNumber:        data.company_details?.registration_number ?? "",
  taxId:            data.company_details?.tax_id              ?? "",
  yearEstablished:  data.company_details?.year_established    ?? "",
  companyType:      data.company_details?.company_type        ?? "",
  userEmail:        data.user_id?.email                       ?? "",
  userPhone:        data.user_id?.phone                       ?? "",
  userFullName:     data.user_id?.full_name                   ?? "",
  avatarUrl:        data.user_id?.avatar_url                  ?? "",
  industry:         data.business_details?.industry_category  ?? "",
  businessNature:   data.business_details?.business_nature    ?? "",
  coverage:         data.business_details?.service_coverage   ?? "",
  country:          data.business_details?.country            ?? "",
  website:          data.online_presence?.website_url         ?? "",
  email:            data.online_presence?.company_email       ?? "",
  phone:            data.online_presence?.phone_number        ?? "",
  addressLine1:     data.online_presence?.address?.address_line1 ?? "",
  addressLine2:     data.online_presence?.address?.address_line2 ?? "",
  city:             data.online_presence?.address?.city       ?? "",
  pincode:          data.online_presence?.address?.pincode    ?? "",
  state:            data.online_presence?.address?.state      ?? "",
  addressCountry:   data.online_presence?.address?.country    ?? "",
  instagram:        data.social_media_links?.instagram        ?? "",
  facebook:         data.social_media_links?.facebook         ?? "",
  linkedin:         data.social_media_links?.linkedin         ?? "",
  twitter:          data.social_media_links?.twitter          ?? "",
  description:      data.company_description                  ?? "",
  profileCompletion: data.profile_completion_percentage       ?? 0,
  validated:        data.validated === true,
  verificationStatus: data.verification_status               ?? "",
  coverImageUrls:   data.cover_image_urls                     ?? [],
});

const mapFormToBody = (form) => ({
  business_details: {
    industry_category: form.industry, business_nature: form.businessNature,
    service_coverage: form.coverage, country: form.country,
  },
  online_presence: {
    website_url: form.website, company_email: form.email, phone_number: form.phone,
    address: {
      address_line1: form.addressLine1, address_line2: form.addressLine2,
      city: form.city, pincode: form.pincode, state: form.state, country: form.addressCountry,
    },
  },
  social_media_links: {
    instagram: form.instagram, facebook: form.facebook,
    linkedin: form.linkedin, twitter: form.twitter,
  },
  company_description: form.description,
  cover_image_urls: form.coverImageUrls,
});

// ─── CompanyInfo ──────────────────────────────────────────────────────────────
const CompanyInfo = () => {
  const { userObject } = useSelector((state) => state.auth);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const [showLogoCropModal, setShowLogoCropModal] = useState(false);
  const [showCoverCropModal, setShowCoverCropModal] = useState(false);
  const [showCoverManager, setShowCoverManager] = useState(false);
  const [showAvatarManager, setShowAvatarManager] = useState(false);
  const [showCompletionReminder, setShowCompletionReminder] = useState(false);
  const [deletingCover, setDeletingCover] = useState(null); // url being deleted
  const [deletingAvatar, setDeletingAvatar] = useState(false);
  const fileRef = useRef();
  const [form, setForm] = useState(EMPTY_FORM);
  const userId = userObject?._id || userObject?.id;

  const handleCoverSuccess = (newUrl) => {
    setForm(prev => ({ ...prev, coverImageUrls: [...prev.coverImageUrls, newUrl] }));
    setShowCoverCropModal(false);
    setShowCoverManager(true);
  };

  const handleAvatarSuccess = (newUrl) => {
    setForm(prev => ({ ...prev, avatarUrl: newUrl }));
    setShowLogoCropModal(false);
    setShowAvatarManager(false);
  };

  const handleDeleteCoverApi = async (imageUrl) => {
    if (!userId) return;
    setDeletingCover(imageUrl);
    try {
      await api.delete(`/vendors/profile/${userId}/cover-image`, { data: { imageUrl } });
      setForm(prev => ({ ...prev, coverImageUrls: prev.coverImageUrls.filter(u => u !== imageUrl) }));
    } catch { /* silently fail – optimistic UI already removed it */ }
    finally { setDeletingCover(null); }
  };

  const handleDeleteAvatar = async () => {
    if (!userId) return;
    setDeletingAvatar(true);
    try {
      await api.delete(`/vendors/profile/${userId}/avatar`);
      setForm(prev => ({ ...prev, avatarUrl: "" }));
      setShowAvatarManager(false);
    } catch { /* ignore */ }
    finally { setDeletingAvatar(false); }
  };

  const handleReorderCovers = (newOrder) => {
    setForm(prev => ({ ...prev, coverImageUrls: newOrder }));
  };

  const fetchProfile = async () => {
    if (!userId) return;
    setLoading(true); setError("");
    try {
      const res = await api.get(`/vendors/profile/${userId}`);
      if (res.data) setForm(mapApiToForm(res.data));
    } catch { setError("Failed to load profile. Please refresh."); }
    finally { setLoading(false); }
  };

  useEffect(() => { fetchProfile(); }, [userId]);

  useEffect(() => {
    if (!loading && form.profileCompletion < 100) {
      setShowCompletionReminder(true);
    }
  }, [loading, form.profileCompletion]);

  const set = (k) => (e) => setForm(p => ({ ...p, [k]: e.target.value }));

  const handleSave = async () => {
    if (!userId) return;
    setSaving(true); setError("");
    try {
      await api.post(`/vendors/profile/${userId}`, mapFormToBody(form));
      await fetchProfile();
      setSaved(true); setEditing(false);
      setTimeout(() => setSaved(false), 3000);
    } catch { setError("Failed to save changes. Please try again."); }
    finally { setSaving(false); }
  };

  const D = !editing;
  const pct = form.profileCompletion;

  if (loading) return (
    <div className="flex flex-col items-center justify-center py-20 gap-3">
      <div className="w-8 h-8 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
      <span className="text-sm text-gray-400">Loading profile…</span>
    </div>
  );

  return (
    <div className="space-y-5">
      {showCompletionReminder && pct < 100 && (
        <CompletionReminderModal
          pct={pct}
          onClose={() => setShowCompletionReminder(false)}
          onEdit={() => {
            setEditing(true);
            setShowCompletionReminder(false);
          }}
        />
      )}
      {saved && (
        <div className="flex items-center gap-2 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-600 dark:text-green-400 px-4 py-3 rounded-xl text-sm font-semibold">
          <CheckCircle2 size={16} /> Profile updated successfully.
        </div>
      )}
      {error && (
        <div className="flex items-center gap-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 px-4 py-3 rounded-xl text-sm font-semibold">
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {/* ── Profile Hero Card ── */}
      <div className="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 overflow-hidden shadow-sm">

        {/* Cover banner */}
        <div className="h-48 md:h-64 bg-gray-100 dark:bg-gray-800 relative overflow-hidden group">
          {form.coverImageUrls && form.coverImageUrls.length > 0 ? (
            <Swiper modules={[Autoplay, Pagination]} autoplay={{ delay: 3500, disableOnInteraction: false }} pagination={{ clickable: true }} className="w-full h-full">
              {form.coverImageUrls.map((url, index) => (
                <SwiperSlide key={index}>
                  <img src={url} alt={`Cover ${index + 1}`} className="w-full h-full object-cover" />
                </SwiperSlide>
              ))}
            </Swiper>
          ) : (
            <div className="w-full h-full bg-gradient-to-r from-orange-400 via-pink-500 to-purple-600 relative">
              <div className="absolute inset-0 opacity-20" style={{ backgroundImage: "radial-gradient(circle, white 1px, transparent 1px)", backgroundSize: "20px 20px" }} />
              <div className="absolute inset-0 flex items-center justify-center"><ImageIcon size={48} className="text-white/20" /></div>
            </div>
          )}
          {/* Manage covers button — always visible */}
          <button
            type="button"
            onClick={() => setShowCoverManager(true)}
            className="absolute top-3 right-3 z-20 flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-black/50 backdrop-blur-sm text-white text-[11px] font-bold hover:bg-black/70 transition-all shadow-lg"
          >
            <Camera size={13} /> {form.coverImageUrls.length > 0 ? "Edit Covers" : "Add Cover"}
          </button>
        </div>

        {/* Avatar + actions row */}
        <div className="px-5 pb-5 bg-gray-50 dark:bg-gray-950/40">
          <div className="flex items-end justify-between -mt-10 relative z-30">
            {/* Avatar — opens AvatarManagerModal */}
            <button
              type="button"
              onClick={() => setShowAvatarManager(true)}
              className="w-[80px] h-[80px] rounded-2xl flex items-center justify-center overflow-hidden bg-white dark:bg-gray-800 border-4 border-white dark:border-gray-900 shadow-xl flex-shrink-0 relative group/av cursor-pointer"
              title="Manage Profile Photo"
            >
              {form.avatarUrl
                ? <img src={form.avatarUrl} alt="logo" className="w-full h-full object-cover" />
                : <span className="text-3xl">🏢</span>}
              <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/av:opacity-100 transition-opacity flex items-center justify-center rounded-xl">
                <Camera size={18} className="text-white" />
              </div>
            </button>

            {/* Edit / Save buttons */}
            <div className="flex gap-2 mb-2">
              {!editing ? (
                <button onClick={() => setEditing(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[11px] font-bold border border-gray-200 dark:border-gray-800 text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-900/50 hover:bg-gray-100 dark:hover:bg-gray-800 transition-all shadow-sm">
                  <Edit3 size={12} /> Edit Profile
                </button>
              ) : (
                <>
                  <button onClick={() => { setEditing(false); setError(""); }}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-full text-[11px] font-bold text-gray-500 border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900/50 hover:bg-gray-100 dark:hover:bg-gray-800 transition-all">
                    <X size={12} /> Cancel
                  </button>
                  <button onClick={handleSave} disabled={saving}
                    className="flex items-center gap-1.5 px-4 py-1.5 rounded-full text-[11px] font-bold bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-md shadow-pink-500/20 disabled:opacity-60 hover:opacity-90 transition-all">
                    {saving ? <Loader2 size={12} className="animate-spin" /> : <Save size={12} />}
                    {saving ? "Saving…" : "Save Changes"}
                  </button>
                </>
              )}
            </div>
          </div>

          {/* Company info */}
          <div className="mt-4">
            <div className="flex flex-wrap items-center gap-2">
              <div className="text-xl font-black text-gray-900 dark:text-white leading-none">{form.companyName || "—"}</div>
              <ValidationStatusBadge validated={form.validated} status={form.verificationStatus} />
            </div>
            <div className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">
              {[form.userFullName, form.userEmail].filter(Boolean).join(" · ")}
            </div>
          </div>
        </div>
      </div>

      {/* Completion bar */}
      <CompletionBar pct={pct} />

      {/* ── Cover Manager Modal ── */}
      {showCoverManager && (
        <CoverManagerModal
          images={form.coverImageUrls}
          onClose={() => setShowCoverManager(false)}
          onAdd={() => { setShowCoverManager(false); setShowCoverCropModal(true); }}
          onDelete={handleDeleteCoverApi}
          onReorder={handleReorderCovers}
          deleting={deletingCover}
        />
      )}

      {/* ── Avatar Manager Modal ── */}
      {showAvatarManager && (
        <AvatarManagerModal
          avatarUrl={form.avatarUrl}
          companyName={form.companyName}
          onClose={() => setShowAvatarManager(false)}
          onUpload={() => { setShowAvatarManager(false); setShowLogoCropModal(true); }}
          onDelete={handleDeleteAvatar}
          deleting={deletingAvatar}
        />
      )}

      {/* Cover Image Crop Modal */}
      <CoverImageCropModal
        isOpen={showCoverCropModal}
        onClose={() => setShowCoverCropModal(false)}
        onSuccess={handleCoverSuccess}
        userId={userId}
      />

      {/* Logo Crop Modal */}
      <AvatarCropModal
        isOpen={showLogoCropModal}
        onClose={() => setShowLogoCropModal(false)}
        onSuccess={handleAvatarSuccess}
        currentAvatar={form.avatarUrl}
        userName={form.companyName || "Logo"}
      />

      {/* Desktop: single grid form */}
      <div className="hidden md:block bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-6 shadow-sm">
        <div className="grid grid-cols-2 gap-x-6 gap-y-4">

          <SectionDivider>Registration Details</SectionDivider>

          <Field label="Company Name" required><Input value={form.companyName} disabled placeholder="Company Name" /></Field>
          <Field label="Registered Name" required><Input value={form.registeredName} disabled placeholder="Legal registered name" /></Field>
          <Field label="Registration Number"><Input value={form.regNumber} disabled placeholder="CIN / Reg. No." /></Field>
          <Field label="Tax ID / VAT / GST"><Input value={form.taxId} disabled placeholder="GSTIN / VAT ID" /></Field>
          <Field label="Year Established"><Input value={form.yearEstablished} disabled placeholder="Year" /></Field>
          <Field label="Company Type"><Input value={form.companyType} disabled placeholder="Company type" /></Field>

          <SectionDivider>Business Details</SectionDivider>

          <Field label="Industry Category">
            <SelectField value={form.industry} onChange={set("industry")} disabled={D}
              options={["Digital Marketing","E-Commerce","FMCG","Healthcare","Education","Finance","Real Estate","Technology","Retail","Shoes","Other"]}
              placeholder="Select industry" />
          </Field>
          <Field label="Business Nature">
            <SelectField value={form.businessNature} onChange={set("businessNature")} disabled={D}
              options={["Advertising Agency","Brand / Advertiser","Publisher","Influencer Network","Reseller","Technology Partner","Manufacturer","Retailer"]}
              placeholder="Select nature" />
          </Field>
          <Field label="Service Coverage">
            <SelectField value={form.coverage} onChange={set("coverage")} disabled={D}
              options={["Pan India","Regional","City-Level","International"]}
              placeholder="Select coverage" />
          </Field>
          <Field label="Country">
            <SelectField value={form.country} onChange={set("country")} disabled={D}
              options={["India","United States","United Kingdom","UAE","Singapore","Australia","Canada"]}
              placeholder="Select country" />
          </Field>

          <SectionDivider>Contact & Online Presence</SectionDivider>

          <Field label="Website URL"><Input type="url" value={form.website} onChange={set("website")} disabled={D} icon="🌐" placeholder="https://yourwebsite.com" /></Field>
          <Field label="Company Email" required><Input type="email" value={form.email} onChange={set("email")} disabled={D} icon="✉️" placeholder="company@email.com" /></Field>
          <Field label="Phone Number"><Input type="tel" value={form.phone} onChange={set("phone")} disabled={D} icon="📞" placeholder="+91 00000 00000" /></Field>
          <Field label="Address Line 1"><Input value={form.addressLine1} onChange={set("addressLine1")} disabled={D} placeholder="Street / Building" /></Field>
          <Field label="Address Line 2"><Input value={form.addressLine2} onChange={set("addressLine2")} disabled={D} placeholder="Area / Locality" /></Field>
          <Field label="City"><Input value={form.city} onChange={set("city")} disabled={D} placeholder="City" /></Field>
          <Field label="Pincode"><Input value={form.pincode} onChange={set("pincode")} disabled={D} placeholder="Pincode" /></Field>
          <Field label="State"><Input value={form.state} onChange={set("state")} disabled={D} placeholder="State" /></Field>
          <Field label="Address Country"><Input value={form.addressCountry} onChange={set("addressCountry")} disabled={D} placeholder="Country" /></Field>

          <SectionDivider>Company Description</SectionDivider>

          <div className="col-span-2">
            <Field label="About the Company">
              <Textarea value={form.description} onChange={set("description")} disabled={D} rows={4}
                placeholder="Describe what your company does, services offered, target audience…" />
            </Field>
          </div>

          <SectionDivider>Social Media Links</SectionDivider>

          <Field label="Instagram">
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-pink-500"><Instagram size={14} /></span>
              <input type="url" value={form.instagram} onChange={set("instagram")} disabled={D} placeholder="https://instagram.com/…" className={`${inputCls} pl-9`} />
            </div>
          </Field>
          <Field label="Facebook">
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-blue-500"><Facebook size={14} /></span>
              <input type="url" value={form.facebook} onChange={set("facebook")} disabled={D} placeholder="https://facebook.com/…" className={`${inputCls} pl-9`} />
            </div>
          </Field>
          <Field label="LinkedIn">
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-blue-700"><Linkedin size={14} /></span>
              <input type="url" value={form.linkedin} onChange={set("linkedin")} disabled={D} placeholder="https://linkedin.com/…" className={`${inputCls} pl-9`} />
            </div>
          </Field>
          <Field label="Twitter / X">
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sky-500"><Twitter size={14} /></span>
              <input type="url" value={form.twitter} onChange={set("twitter")} disabled={D} placeholder="https://twitter.com/…" className={`${inputCls} pl-9`} />
            </div>
          </Field>

        </div>
      </div>

      {/* Mobile: collapsible accordions */}
      <div className="md:hidden space-y-3">
        <CollapsibleSection title="Registration Details" icon={Building2} defaultOpen>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Company Name" required><Input value={form.companyName} disabled placeholder="Company Name" /></Field>
            <Field label="Registered Name" required><Input value={form.registeredName} disabled placeholder="Legal name" /></Field>
            <Field label="Reg. Number"><Input value={form.regNumber} disabled placeholder="CIN / Reg. No." /></Field>
            <Field label="Tax ID / GST"><Input value={form.taxId} disabled placeholder="GSTIN" /></Field>
            <Field label="Year Est."><Input value={form.yearEstablished} disabled placeholder="Year" /></Field>
            <Field label="Type"><Input value={form.companyType} disabled placeholder="Type" /></Field>
          </div>
        </CollapsibleSection>

        <CollapsibleSection title="Business Details" icon={Globe} iconColor="text-blue-500" defaultOpen>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Industry">
              <SelectField value={form.industry} onChange={set("industry")} disabled={D}
                options={["Digital Marketing","E-Commerce","FMCG","Healthcare","Education","Finance","Real Estate","Technology","Retail","Shoes","Other"]}
                placeholder="Industry" />
            </Field>
            <Field label="Nature">
              <SelectField value={form.businessNature} onChange={set("businessNature")} disabled={D}
                options={["Advertising Agency","Brand / Advertiser","Publisher","Influencer Network","Reseller","Technology Partner","Manufacturer","Retailer"]}
                placeholder="Nature" />
            </Field>
            <Field label="Coverage">
              <SelectField value={form.coverage} onChange={set("coverage")} disabled={D}
                options={["Pan India","Regional","City-Level","International"]} placeholder="Coverage" />
            </Field>
            <Field label="Country">
              <SelectField value={form.country} onChange={set("country")} disabled={D}
                options={["India","United States","United Kingdom","UAE","Singapore","Australia","Canada"]} placeholder="Country" />
            </Field>
          </div>
        </CollapsibleSection>

        <CollapsibleSection title="Contact & Address" icon={MapPin} iconColor="text-green-500">
          <div className="space-y-3">
            <Field label="Website URL"><Input type="url" value={form.website} onChange={set("website")} disabled={D} icon="🌐" placeholder="https://yourwebsite.com" /></Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Company Email" required><Input type="email" value={form.email} onChange={set("email")} disabled={D} icon="✉️" placeholder="company@email.com" /></Field>
              <Field label="Phone"><Input type="tel" value={form.phone} onChange={set("phone")} disabled={D} icon="📞" placeholder="+91" /></Field>
            </div>
            <Field label="Address Line 1"><Input value={form.addressLine1} onChange={set("addressLine1")} disabled={D} placeholder="Street / Building" /></Field>
            <Field label="Address Line 2"><Input value={form.addressLine2} onChange={set("addressLine2")} disabled={D} placeholder="Area / Locality" /></Field>
            <div className="grid grid-cols-3 gap-3">
              <Field label="City"><Input value={form.city} onChange={set("city")} disabled={D} placeholder="City" /></Field>
              <Field label="Pincode"><Input value={form.pincode} onChange={set("pincode")} disabled={D} placeholder="Pincode" /></Field>
              <Field label="State"><Input value={form.state} onChange={set("state")} disabled={D} placeholder="State" /></Field>
            </div>
          </div>
        </CollapsibleSection>

        <CollapsibleSection title="Company Description" icon={Edit3} iconColor="text-purple-500">
          <Field label="About the Company">
            <Textarea value={form.description} onChange={set("description")} disabled={D} rows={4}
              placeholder="Describe what your company does…" />
          </Field>
        </CollapsibleSection>

        <CollapsibleSection title="Social Media Links" icon={Globe} iconColor="text-orange-500">
          <div className="space-y-3">
            {[
              { label: "Instagram", key: "instagram", color: "text-pink-500", Icon: Instagram },
              { label: "Facebook",  key: "facebook",  color: "text-blue-500", Icon: Facebook },
              { label: "LinkedIn",  key: "linkedin",  color: "text-blue-700", Icon: Linkedin },
              { label: "Twitter / X", key: "twitter", color: "text-sky-500",  Icon: Twitter },
            ].map(({ label, key, color, Icon }) => (
              <Field key={key} label={label}>
                <div className="relative">
                  <span className={`absolute left-3 top-1/2 -translate-y-1/2 ${color}`}><Icon size={14} /></span>
                  <input type="url" value={form[key]} onChange={set(key)} disabled={D}
                    placeholder={`https://${key}.com/…`} className={`${inputCls} pl-9`} />
                </div>
              </Field>
            ))}
          </div>
        </CollapsibleSection>
      </div>

      {/* Floating save bar when editing (mobile) */}
      {editing && (
        <div className="md:hidden fixed bottom-[68px] left-4 right-4 z-40 bg-gray-900 dark:bg-gray-950 rounded-2xl shadow-2xl shadow-black/40 flex items-center justify-between px-4 py-3 border border-gray-800">
          <span className="text-xs font-semibold text-gray-300">Unsaved changes</span>
          <div className="flex gap-2">
            <button onClick={() => { setEditing(false); setError(""); }}
              className="px-3 py-1.5 rounded-xl text-xs font-bold text-gray-400 border border-gray-700 active:scale-95 transition-all">
              Discard
            </button>
            <button onClick={handleSave} disabled={saving}
              className="flex items-center gap-1.5 px-4 py-1.5 rounded-xl text-xs font-bold bg-gradient-to-r from-orange-500 to-pink-600 text-white disabled:opacity-60 active:scale-95 transition-all">
              {saving ? <Loader2 size={11} className="animate-spin" /> : <Save size={11} />}
              {saving ? "Saving…" : "Save"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

// ─── PrimaryContact ───────────────────────────────────────────────────────────
const PrimaryContact = () => {
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [newContact, setNewContact] = useState({ name: "", email: "", phone: "", position: "", notes: "" });
  const [addError, setAddError] = useState("");

  const fetchContacts = async () => {
    if (!userId) return;
    setLoading(true);
    try { const res = await api.get(`/vendors/${userId}/contacts`); setContacts(res.data || []); }
    catch { setError("Failed to load contacts."); }
    finally { setLoading(false); }
  };

  useEffect(() => { fetchContacts(); }, [userId]);

  const toggleEdit = (id) => setContacts(c => c.map(x => x._id === id ? { ...x, editing: !x.editing } : x));
  const setField = (id, k, v) => setContacts(c => c.map(x => x._id === id ? { ...x, [k]: v } : x));

  const remove = async (id) => {
    if (!window.confirm("Remove this contact?")) return;
    try { await api.delete(`/vendors/${userId}/contacts/${id}`); setContacts(c => c.filter(x => x._id !== id)); }
    catch { alert("Failed to delete contact."); }
  };

  const saveEdit = async (contact) => {
    try {
      await api.put(`/vendors/${userId}/contacts/${contact._id}`, {
        name: contact.name, email: contact.email, phone: contact.phone,
        position: contact.position, notes: contact.notes,
      });
      toggleEdit(contact._id);
    } catch { alert("Failed to update contact."); }
  };

  const setNew = (k) => (e) => setNewContact(p => ({ ...p, [k]: e.target.value }));

  const saveNew = async () => {
    if (!(newContact.name || "").trim() || !(newContact.email || "").trim()) { setAddError("Name and Email are required."); return; }
    setSaving(true);
    try {
      const res = await api.post(`/vendors/${userId}/contacts`, { ...newContact });
      setContacts(prev => [...prev, res.data]);
      setAddOpen(false);
    } catch (err) { setAddError(err.response?.data?.message || "Failed to add contact."); }
    finally { setSaving(false); }
  };

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Primary Contact Persons</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Manage who handles communications and ad approvals.</p>
        </div>
        <button onClick={() => { setAddError(""); setNewContact({ name:"",email:"",phone:"",position:"",notes:"" }); setAddOpen(true); }}
          className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold bg-gray-900 dark:bg-white text-white dark:text-black shadow-sm hover:opacity-90 transition-all">
          <Plus size={14} /> Add Contact
        </button>
      </div>

      {loading && <div className="text-center py-10 text-gray-400 text-sm">Loading…</div>}
      {error && <div className="text-center py-10 text-red-500 text-sm">{error}</div>}

      {addOpen && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm" onClick={e => e.target === e.currentTarget && setAddOpen(false)}>
          <div className="w-full sm:max-w-lg rounded-t-3xl sm:rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl overflow-hidden">
            <div className="sm:hidden flex justify-center pt-3 pb-1"><div className="w-10 h-1 rounded-full bg-gray-200 dark:bg-gray-700" /></div>
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
              <div>
                <div className="text-base font-black text-gray-900 dark:text-white">Add Contact</div>
                <div className="text-xs text-gray-500 mt-0.5">Add a primary contact person</div>
              </div>
              <button onClick={() => setAddOpen(false)} className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-gray-400"><X size={16} /></button>
            </div>
            <div className="p-5 space-y-3 max-h-[60vh] overflow-y-auto">
              {addError && <div className="flex items-center gap-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 text-xs px-3 py-2 rounded-xl font-semibold"><AlertCircle size={14}/>{addError}</div>}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <Field label="Full Name" required><Input value={newContact.name} onChange={setNew("name")} placeholder="Full Name" /></Field>
                <Field label="Position"><Input value={newContact.position} onChange={setNew("position")} placeholder="e.g. Marketing Head" /></Field>
                <Field label="Email" required><Input type="email" value={newContact.email} onChange={setNew("email")} icon="✉️" placeholder="email@company.com" /></Field>
                <Field label="Phone"><Input type="tel" value={newContact.phone} onChange={setNew("phone")} icon="📱" placeholder="+91 00000 00000" /></Field>
              </div>
              <Field label="Notes"><Input value={newContact.notes} onChange={setNew("notes")} placeholder="Additional notes…" /></Field>
            </div>
            <div className="px-5 py-4 border-t border-gray-100 dark:border-gray-800 flex gap-3">
              <button onClick={() => setAddOpen(false)} disabled={saving} className="flex-1 py-3 rounded-2xl text-sm font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-200">Cancel</button>
              <button onClick={saveNew} disabled={saving} className="flex-1 py-3 rounded-2xl text-sm font-bold bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-lg shadow-pink-500/20 disabled:opacity-60 flex items-center justify-center gap-2">
                {saving && <Loader2 size={13} className="animate-spin" />} Add Contact
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="grid gap-4">
        {contacts.map(c => (
          <div key={c._id} className="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 overflow-hidden hover:border-gray-200 dark:hover:border-gray-700 transition-colors">
            <div className="flex items-center gap-3 px-4 py-4">
              <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 text-white font-black text-lg flex items-center justify-center flex-shrink-0">
                {c.name ? c.name[0].toUpperCase() : "?"}
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-bold text-gray-900 dark:text-white truncate">{c.name || "Contact"}</div>
                <div className="text-xs text-gray-500 dark:text-gray-400 truncate">{c.position}</div>
                {!c.editing && (
                  <div className="flex flex-wrap gap-2 mt-1.5">
                    {c.email && <span className="flex items-center gap-1 text-[10px] text-gray-400 bg-gray-50 dark:bg-gray-800 px-2 py-0.5 rounded-lg"><Mail size={9}/>{c.email}</span>}
                    {c.phone && <span className="flex items-center gap-1 text-[10px] text-gray-400 bg-gray-50 dark:bg-gray-800 px-2 py-0.5 rounded-lg"><Phone size={9}/>{c.phone}</span>}
                  </div>
                )}
              </div>
              <div className="flex gap-1.5 flex-shrink-0">
                <button onClick={() => c.editing ? saveEdit(c) : toggleEdit(c._id)}
                  className={`p-2 rounded-xl text-xs transition-colors ${c.editing ? "bg-green-100 dark:bg-green-900/30 text-green-600" : "bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"}`}>
                  {c.editing ? <Check size={14} /> : <Edit3 size={14} />}
                </button>
                <button onClick={() => remove(c._id)} className="p-2 rounded-xl bg-red-50 dark:bg-red-900/20 text-red-500 hover:bg-red-100 dark:hover:bg-red-900/30 transition-colors">
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
            {c.editing && (
              <div className="px-4 pb-4 pt-2 border-t border-gray-50 dark:border-gray-800 grid grid-cols-1 md:grid-cols-2 gap-3">
                <Field label="Full Name" required><Input value={c.name} onChange={e => setField(c._id, "name", e.target.value)} placeholder="Full Name" /></Field>
                <Field label="Position"><Input value={c.position} onChange={e => setField(c._id, "position", e.target.value)} placeholder="Position" /></Field>
                <Field label="Email" required><Input type="email" value={c.email} onChange={e => setField(c._id, "email", e.target.value)} icon="✉️" placeholder="email@company.com" /></Field>
                <Field label="Phone"><Input type="tel" value={c.phone} onChange={e => setField(c._id, "phone", e.target.value)} icon="📱" placeholder="+91" /></Field>
                <div className="md:col-span-2"><Field label="Notes"><Input value={c.notes} onChange={e => setField(c._id, "notes", e.target.value)} placeholder="Notes…" /></Field></div>
              </div>
            )}
          </div>
        ))}
        {!loading && contacts.length === 0 && (
          <div className="flex flex-col items-center py-16 gap-3 rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-700">
            <User size={32} className="text-gray-300 dark:text-gray-600" />
            <p className="text-sm text-gray-400">No contacts yet</p>
            <button onClick={() => { setAddError(""); setAddOpen(true); }} className="text-xs font-semibold text-pink-500 hover:underline">+ Add your first contact</button>
          </div>
        )}
      </div>
    </div>
  );
};

// ─── SalesOfficer ─────────────────────────────────────────────────────────────
const SalesOfficer = () => {
  const [officer, setOfficer] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const load = async () => {
      setLoading(true); setError("");
      try { const res = await api.get("/sales/my-officer"); setOfficer(res.data?.assigned_sales_officer || null); }
      catch { setError("Failed to load sales officer details."); }
      finally { setLoading(false); }
    };
    load();
  }, []);

  const initials = (name) =>
    (name || "").split(" ").filter(Boolean).slice(0, 2).map(p => p[0]?.toUpperCase()).join("") || "?";

  if (loading) return (
    <div className="flex flex-col items-center justify-center py-20 gap-3">
      <div className="w-8 h-8 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
      <span className="text-sm text-gray-400">Loading…</span>
    </div>
  );

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Associated Sales Officer</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Your dedicated account manager from our sales team.</p>
        </div>
        <span className="flex items-center gap-1.5 text-[10px] font-bold px-3 py-1.5 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 uppercase tracking-widest">
          <Shield size={10} /> Read Only
        </span>
      </div>

      {error && (
        <div className="flex items-center gap-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 px-4 py-3 rounded-xl text-sm font-semibold">
          <AlertCircle size={16}/>{error}
        </div>
      )}

      {!error && !officer && (
        <div className="flex flex-col items-center py-20 gap-4 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
          <div className="w-20 h-20 rounded-full bg-gradient-to-br from-orange-100 to-pink-100 dark:from-orange-900/30 dark:to-pink-900/30 flex items-center justify-center">
            <Handshake size={36} className="text-orange-400" />
          </div>
          <div className="text-center">
            <p className="text-base font-bold text-gray-700 dark:text-gray-300">No Sales Officer Assigned</p>
            <p className="text-sm text-gray-400 dark:text-gray-500 mt-1 max-w-xs mx-auto">A dedicated sales account manager will be assigned to your account soon.</p>
          </div>
          {/* Informational badges */}
          <div className="flex flex-wrap justify-center gap-2 mt-2">
            {["Personalized support", "Ad campaign guidance", "Priority access"].map(tag => (
              <span key={tag} className="flex items-center gap-1 text-[11px] font-semibold text-orange-600 dark:text-orange-400 bg-orange-50 dark:bg-orange-900/20 px-3 py-1 rounded-full">
                <Star size={9} /> {tag}
              </span>
            ))}
          </div>
        </div>
      )}

      {officer && (
        <div className="space-y-4">
          {/* Officer Hero Card */}
          <div className="rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 overflow-hidden shadow-sm">
            {/* Gradient banner */}
            <div className="h-28 bg-gradient-to-r from-orange-400 via-pink-500 to-purple-600 relative overflow-hidden">
              <div className="absolute inset-0 opacity-20" style={{backgroundImage:'radial-gradient(circle, white 1px, transparent 1px)', backgroundSize:'16px 16px'}} />
              {/* Badge in top-right */}
              <div className="absolute top-3 right-3 flex items-center gap-1 bg-white/20 backdrop-blur-sm text-white text-[10px] font-bold px-2.5 py-1 rounded-full border border-white/30">
                <BadgeCheck size={11} /> Sales Team
              </div>
            </div>

            <div className="px-5 pb-6">
              {/* Avatar + action row */}
              <div className="flex items-end justify-between" style={{ marginTop: "-36px" }}>
                {/* Avatar */}
                <div className="w-[72px] h-[72px] rounded-2xl overflow-hidden bg-white dark:bg-gray-800 border-4 border-white dark:border-gray-900 shadow-xl flex-shrink-0 flex items-center justify-center">
                  {officer.avatar_url
                    ? <img src={officer.avatar_url} alt="" className="w-full h-full object-cover" />
                    : <span className="text-white font-black text-xl w-full h-full flex items-center justify-center bg-gradient-to-br from-orange-400 to-pink-600">{initials(officer.full_name || officer.username)}</span>
                  }
                </div>
                {/* Email button */}
                {officer.email && (
                  <a href={`mailto:${officer.email}`}
                    className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold bg-gradient-to-r from-orange-500 to-pink-600 text-white hover:opacity-90 shadow-md shadow-pink-500/20 transition-all mb-1">
                    <Mail size={12} /> Email Officer
                  </a>
                )}
              </div>

              {/* Name + role */}
              <div className="mt-3">
                <div className="flex items-center gap-2">
                  <div className="text-base font-black text-gray-900 dark:text-white">{officer.full_name || officer.username || "Sales Officer"}</div>
                  <BadgeCheck size={16} className="text-pink-500 flex-shrink-0" />
                </div>
                <div className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
                  Sales Account Manager{officer.username && ` · @${officer.username}`}
                </div>

                {/* Contact chips */}
                <div className="flex flex-wrap gap-2 mt-3">
                  {officer.email && (
                    <a href={`mailto:${officer.email}`} className="flex items-center gap-1 text-xs text-gray-500 bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 px-2.5 py-1 rounded-lg border border-gray-100 dark:border-gray-700 transition-colors">
                      <Mail size={11} className="text-pink-500"/>{officer.email}
                    </a>
                  )}
                  {officer.phone && (
                    <a href={`tel:${officer.phone}`} className="flex items-center gap-1 text-xs text-gray-500 bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 px-2.5 py-1 rounded-lg border border-gray-100 dark:border-gray-700 transition-colors">
                      <Phone size={11} className="text-green-500"/>{officer.phone}
                    </a>
                  )}
                  {officer.location && (
                    <span className="flex items-center gap-1 text-xs text-gray-500 bg-gray-50 dark:bg-gray-800 px-2.5 py-1 rounded-lg border border-gray-100 dark:border-gray-700">
                      <MapPin size={11} className="text-blue-500"/>{officer.location}
                    </span>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Details grid card */}
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-5">
            <p className="text-[10px] font-black text-pink-500 uppercase tracking-widest mb-4">Officer Details</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-0 divide-y divide-gray-50 dark:divide-gray-800 sm:divide-y-0 sm:divide-x sm:divide-gray-100 sm:dark:divide-gray-800">
              {[
                ["Name",     officer.full_name || officer.username || "—"],
                ["Username", officer.username ? `@${officer.username}` : "—"],
                ["Email",    officer.email || "—"],
                ["Phone",    officer.phone || "—"],
                ["Location", officer.location || "—"],
              ].map(([label, value]) => (
                <div key={label} className="py-3 sm:px-4 first:sm:pl-0 last:sm:pr-0">
                  <div className="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-1">{label}</div>
                  <div className="text-sm font-semibold text-gray-900 dark:text-white break-all">{value}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Info banner */}
          <div className="flex items-start gap-3 bg-orange-50 dark:bg-orange-900/20 border border-orange-100 dark:border-orange-800/30 rounded-2xl px-4 py-3.5">
            <div className="w-8 h-8 rounded-full bg-orange-100 dark:bg-orange-900/40 flex items-center justify-center flex-shrink-0 mt-0.5">
              <Shield size={14} className="text-orange-500" />
            </div>
            <div>
              <p className="text-xs font-bold text-orange-700 dark:text-orange-400">Your dedicated account manager</p>
              <p className="text-xs text-orange-600/80 dark:text-orange-400/70 mt-0.5">
                Reach out to your sales officer for campaign strategy, ad approvals, and priority support.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// ─── Root Component ───────────────────────────────────────────────────────────
export default function VendorProfile() {
  const [tab, setTab] = useState(0);

  const TABS = [
    { label: "Company Information", mobileLabel: "Company", icon: Building2 },
    { label: "Primary Contact",     mobileLabel: "Contacts", icon: User },
    { label: "Sales Officer",       mobileLabel: "Sales",    icon: Handshake },
  ];

  const tabContent = [<CompanyInfo />, <PrimaryContact />, <SalesOfficer />];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">

      {/* Desktop layout */}
      <div className="hidden md:block max-w-7xl mx-auto p-6 md:p-8">
        <div className="mb-8">
          <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">Vendor Profile</span>
          </h1>
          <p className="text-gray-500 dark:text-gray-400">Manage your business identity, team, and account settings</p>
        </div>

        {/* Desktop tab pills */}
        <div className="flex flex-wrap gap-1 mb-8 p-1.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl w-fit shadow-sm">
          {TABS.map((t, i) => {
            const Icon = t.icon;
            return (
              <button key={i} onClick={() => setTab(i)}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold transition-all duration-200 ${tab === i ? "bg-gray-900 dark:bg-white text-white dark:text-black shadow-md" : "text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"}`}>
                <Icon size={15} /> {t.label}
              </button>
            );
          })}
        </div>

        <div>{tabContent[tab]}</div>
      </div>

      {/* Mobile layout */}
      <div className="md:hidden flex flex-col min-h-screen">
        <div className="sticky top-[52px] z-20 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 pt-3 pb-0">
          <h1 className="text-xl font-extrabold mb-3 bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
            Vendor Profile
          </h1>
          <div className="flex gap-0">
            {TABS.map((t, i) => {
              const Icon = t.icon;
              return (
                <button key={i} onClick={() => setTab(i)}
                  className={`flex-1 flex flex-col items-center gap-0.5 py-2.5 text-[11px] font-bold transition-all border-b-2 ${tab === i ? "border-[#fa3f5e] text-[#fa3f5e]" : "border-transparent text-gray-400"}`}>
                  <Icon size={16} />
                  {t.mobileLabel}
                </button>
              );
            })}
          </div>
        </div>

        <div className="flex-1 p-4 pb-28">
          {tabContent[tab]}
        </div>
      </div>
    </div>
  );
}