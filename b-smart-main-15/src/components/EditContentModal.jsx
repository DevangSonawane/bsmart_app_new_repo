import React, { useEffect, useMemo, useState } from 'react';
import {
  MapPin, Smile, Tag, X, ChevronDown, ChevronUp,
  MousePointerClick, Globe, Phone, Mail, Link2, Megaphone,
  Users, Target, CheckCircle2, Info,
} from 'lucide-react';
import api from '../lib/api';

// ── Helpers ───────────────────────────────────────────────────────────────────
const splitList = (value) =>
  String(value || '').split(',').map(item => item.trim()).filter(Boolean);

const normalizeHashTags = (value) =>
  splitList(value).map(item => item.replace(/^#+/, ''));

const getInitialValues = (contentType, item) => ({
  caption: item?.caption || '',
  location: item?.location || '',
  hashtags:
    contentType === 'ad'
      ? (item?.hashtags || []).map(tag => String(tag).replace(/^#+/, '')).join(', ')
      : (item?.tags || []).map(tag => String(tag).replace(/^#+/, '')).join(', '),
  category: item?.category || '',
  targetLanguage: Array.isArray(item?.target_language) ? item.target_language.join(', ') : '',
  targetLocation: Array.isArray(item?.target_location) ? item.target_location.join(', ') : '',
  targetStates: Array.isArray(item?.target_states) ? item.target_states.join(', ') : '',
  totalBudgetCoins: item?.total_budget_coins != null ? String(item.total_budget_coins) : '',
  hideLikes: !!(item?.engagement_controls?.hide_likes_count ?? item?.hide_likes_count),
  disableComments: !!(item?.engagement_controls?.disable_comments ?? item?.turn_off_commenting),
  // CTA fields (Step 3)
  ctaType: item?.cta?.type || item?.cta_type || '',
  ctaUrl: item?.cta?.url || item?.cta_url || '',
  ctaDeepLink: item?.cta?.deep_link || '',
  ctaPhone: item?.cta?.phone || '',
  ctaWhatsapp: item?.cta?.whatsapp || '',
  ctaEmail: item?.cta?.email || '',
  // Audience targeting (Step 4)
  ageMin: item?.targeting?.age_min ? String(item.targeting.age_min) : '13',
  ageMax: item?.targeting?.age_max ? String(item.targeting.age_max) : '65',
  gender: item?.targeting?.gender || 'all',
  targetCountries: Array.isArray(item?.targeting?.countries) ? item.targeting.countries : [],
  targetStatesList: Array.isArray(item?.targeting?.states) ? item.targeting.states : [],
  keywords: Array.isArray(item?.keywords) ? item.keywords : [],
});

const getEndpoint = (contentType, itemId) => {
  if (contentType === 'ad') return `/ads/${itemId}/metadata`;
  if (contentType === 'reel') return `/posts/reels/${itemId}/metadata`;
  return `/posts/${itemId}/metadata`;
};

const getPreviewUrl = (mediaItem) =>
  mediaItem?.fileUrl || mediaItem?.url ||
  mediaItem?.thumbnail?.[0]?.fileUrl ||
  mediaItem?.thumbnails?.[0]?.fileUrl || '';

// ── Sub-components ────────────────────────────────────────────────────────────
function ToggleRow({ label, checked, onToggle }) {
  return (
    <button
      type="button"
      onClick={onToggle}
      className="flex w-full items-center justify-between gap-4 text-left text-[15px] text-white"
    >
      <span>{label}</span>
      <span className={`relative inline-flex h-6 w-11 shrink-0 rounded-full transition-colors ${checked ? 'bg-[#4f8cff]' : 'bg-white/15'}`}>
        <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${checked ? 'translate-x-5' : 'translate-x-0.5'}`} />
      </span>
    </button>
  );
}

function AccordionSection({ icon: Icon, title, subtitle, isOpen, onToggle, children, accentColor = 'indigo' }) {
  const accent = {
    indigo: 'text-indigo-400',
    orange: 'text-orange-400',
    blue: 'text-blue-400',
    purple: 'text-purple-400',
    pink: 'text-pink-400',
  }[accentColor] || 'text-indigo-400';

  return (
    <div className="border border-white/10 rounded-xl overflow-hidden">
      <button
        type="button"
        onClick={onToggle}
        className="w-full flex items-center justify-between px-4 py-3 bg-white/5 hover:bg-white/8 transition-colors"
      >
        <div className="flex items-center gap-2.5">
          {Icon && <Icon size={15} className={accent} />}
          <div className="text-left">
            <p className="text-[13px] font-semibold text-white">{title}</p>
            {subtitle && <p className="text-[11px] text-white/40">{subtitle}</p>}
          </div>
        </div>
        {isOpen
          ? <ChevronUp size={15} className="text-white/40" />
          : <ChevronDown size={15} className="text-white/40" />
        }
      </button>
      {isOpen && (
        <div className="px-4 py-4 bg-black/20 space-y-3 border-t border-white/10">
          {children}
        </div>
      )}
    </div>
  );
}

function FieldInput({ label, value, onChange, placeholder, type = 'text', icon: Icon }) {
  return (
    <div className="space-y-1.5">
      {label && <p className="text-[11px] font-semibold text-white/50 uppercase tracking-wider">{label}</p>}
      <div className="relative">
        {Icon && (
          <div className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30">
            <Icon size={13} />
          </div>
        )}
        <input
          type={type}
          value={value}
          onChange={e => onChange(e.target.value)}
          placeholder={placeholder}
          className={`w-full bg-white/8 border border-white/10 rounded-lg py-2.5 text-[13px] text-white placeholder:text-white/30 outline-none focus:border-white/30 focus:ring-1 focus:ring-white/10 transition-all ${Icon ? 'pl-9 pr-3' : 'px-3'}`}
        />
      </div>
    </div>
  );
}

const CTA_TYPES = [
  { value: 'view_site',    label: 'View Site',    icon: Globe },
  { value: 'contact_info', label: 'Contact',      icon: Info },
  { value: 'install_app',  label: 'Install App',  icon: Megaphone },
  { value: 'book_now',     label: 'Book Now',     icon: CheckCircle2 },
  { value: 'learn_more',   label: 'Learn More',   icon: MousePointerClick },
  { value: 'call_now',     label: 'Call Now',     icon: Phone },
];

const GENDER_OPTIONS = [
  { value: 'all',    label: 'All' },
  { value: 'male',   label: 'Male' },
  { value: 'female', label: 'Female' },
  { value: 'other',  label: 'Other' },
];

// ── Main Modal ────────────────────────────────────────────────────────────────
export default function EditContentModal({ isOpen, onClose, item, contentType = 'post', onSaved }) {
  const [form, setForm]     = useState(getInitialValues(contentType, item));
  const [saving, setSaving] = useState(false);
  const [error, setError]   = useState('');
  const [openSection, setOpenSection] = useState(null);
  const [keywordInput, setKeywordInput] = useState('');

  const isAd = contentType === 'ad';

  useEffect(() => {
    if (isOpen) {
      setForm(getInitialValues(contentType, item));
      setSaving(false);
      setError('');
      setOpenSection(null);
      setKeywordInput('');
    }
  }, [isOpen, contentType, item]);

  const itemId     = item?._id || item?.post_id || item?.id;
  const profile    = typeof item?.user_id === 'object' ? item.user_id : {};
  const username   = profile?.username || profile?.full_name || 'user';
  const fullName   = profile?.full_name || '';
  const avatarUrl  = profile?.avatar_url || '';
  const previewMedia = item?.media?.[0];
  const previewUrl = getPreviewUrl(previewMedia);
  const isVideo    = previewMedia?.type === 'video' || previewMedia?.media_type === 'video';

  const updateField = (key, value) => setForm(prev => ({ ...prev, [key]: value }));
  const toggleSection = (id) => setOpenSection(prev => prev === id ? null : id);

  const addKeyword = () => {
    const kw = keywordInput.trim();
    if (kw && !form.keywords.includes(kw)) {
      updateField('keywords', [...form.keywords, kw]);
    }
    setKeywordInput('');
  };

  const handleSubmit = async (e) => {
    if (e?.preventDefault) e.preventDefault();
    setSaving(true);
    setError('');

    const hashtagList = normalizeHashTags(form.hashtags);

    const payload = isAd
      ? {
          caption: form.caption,
          location: form.location,
          hashtags: hashtagList,
          tags: hashtagList,
          tagged_users: item?.tagged_users || [],
          engagement_controls: {
            hide_likes_count: !!form.hideLikes,
            disable_comments: !!form.disableComments,
          },
          content_type: item?.content_type || 'reel',
          category: form.category,
          target_language: splitList(form.targetLanguage),
          target_location: splitList(form.targetLocation),
          target_states: splitList(form.targetStates),
          total_budget_coins: Number(form.totalBudgetCoins || 0),
          target_preferences: Array.isArray(item?.target_preferences) ? item.target_preferences : [],
          keywords: form.keywords,
          // CTA (Step 3)
          cta: form.ctaType ? {
            type: form.ctaType,
            url: form.ctaUrl,
            deep_link: form.ctaDeepLink,
            phone: form.ctaPhone,
            whatsapp: form.ctaWhatsapp,
            email: form.ctaEmail,
          } : item?.cta || {},
          // Targeting (Step 4)
          targeting: {
            ...(item?.targeting || {}),
            age_min: Number(form.ageMin) || 13,
            age_max: Number(form.ageMax) || 65,
            gender: form.gender,
            countries: form.targetCountries,
            states: form.targetStatesList,
          },
        }
      : {
          caption: form.caption,
          location: form.location,
          tags: hashtagList,
          people_tags: item?.people_tags || [],
          hide_likes_count: !!form.hideLikes,
          turn_off_commenting: !!form.disableComments,
        };

    try {
      const { data } = await api.patch(getEndpoint(contentType, itemId), payload);
      onSaved?.(data);
      onClose?.();
    } catch (err) {
      setError(err?.response?.data?.message || 'Failed to save changes.');
    } finally {
      setSaving(false);
    }
  };

  if (!isOpen || !itemId) return null;

  return (
    <div className="fixed inset-0 z-[90] flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm p-0 sm:p-6">
      <div className="flex w-full max-w-[1060px] sm:h-[92vh] h-[97vh] flex-col overflow-hidden sm:rounded-[28px] rounded-t-[24px] border border-white/10 bg-[#1a1b1f] text-white shadow-[0_30px_100px_rgba(0,0,0,0.8)]">

        {/* ── Header ─────────────────────────────────────────────────────── */}
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4 shrink-0">
          <button
            onClick={onClose}
            className="flex items-center gap-1.5 text-[14px] font-medium text-white/70 hover:text-white transition-colors"
          >
            <X size={16} /> Cancel
          </button>
          <h3 className="text-[15px] font-bold">
            {isAd ? 'Edit Ad' : 'Edit info'}
          </h3>
          <button
            type="button"
            onClick={handleSubmit}
            disabled={saving}
            className="text-[14px] font-bold text-[#4f8cff] hover:text-[#76a3ff] disabled:opacity-50 transition-colors flex items-center gap-1.5"
          >
            {saving ? (
              <>
                <svg className="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                </svg>
                Saving…
              </>
            ) : 'Done'}
          </button>
        </div>

        {/* ── Body ───────────────────────────────────────────────────────── */}
        <div className="grid min-h-0 flex-1 md:grid-cols-[1.72fr_0.95fr] overflow-hidden">

          {/* Left — media preview */}
          <div className="flex min-h-[220px] items-center justify-center overflow-hidden bg-black relative">
            {previewUrl ? (
              isVideo ? (
                <video src={previewUrl} className="h-full max-h-full w-full object-contain" controls muted />
              ) : (
                <img src={previewUrl} alt="Preview" className="h-full max-h-full w-full object-contain" />
              )
            ) : (
              <div className="flex h-full min-h-[220px] w-full items-center justify-center bg-[#111216] text-white/30 text-sm">
                No Preview
              </div>
            )}
            <div className="absolute left-3 top-3 rounded-full bg-black/60 px-3 py-1.5 text-[11px] text-white/80 shadow">
              Click photo to tag people
            </div>
          </div>

          {/* Right — fields */}
          <div className="flex min-h-0 flex-col bg-[#23242a] overflow-y-auto">

            {/* User info */}
            <div className="flex items-center gap-3 border-b border-white/10 px-4 py-4 shrink-0">
              <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-white/10 text-sm font-semibold shrink-0">
                {avatarUrl
                  ? <img src={avatarUrl} alt="" className="h-full w-full object-cover" />
                  : <span>{username[0]?.toUpperCase()}</span>
                }
              </div>
              <div className="min-w-0">
                <p className="truncate text-[14px] font-semibold">{username}</p>
                {fullName && <p className="truncate text-xs text-white/40">{fullName}</p>}
              </div>
            </div>

            <div className="flex-1 overflow-y-auto">

              {/* ── Caption ── */}
              <div className="border-b border-white/10 px-4 py-4">
                <textarea
                  value={form.caption}
                  onChange={e => updateField('caption', e.target.value)}
                  rows={4}
                  className="w-full resize-none bg-transparent text-[14px] leading-7 text-white outline-none placeholder:text-white/30"
                  placeholder="Write a caption..."
                />
                <div className="mt-2 flex items-center justify-between text-white/35">
                  <Smile size={17} />
                  <span className="text-[11px]">{form.caption.length}/2,200</span>
                </div>
              </div>

              {/* ── Location ── */}
              <div className="flex items-center gap-3 border-b border-white/10 px-4 py-3.5">
                <MapPin size={16} className="shrink-0 text-white/40" />
                <input
                  value={form.location}
                  onChange={e => updateField('location', e.target.value)}
                  className="w-full bg-transparent text-[14px] font-medium text-white outline-none placeholder:font-normal placeholder:text-white/35"
                  placeholder="Add location"
                />
                {form.location && (
                  <button type="button" onClick={() => updateField('location', '')} className="shrink-0 text-white/40 hover:text-white transition-colors">
                    <X size={16} />
                  </button>
                )}
              </div>

              {/* ── Hashtags ── */}
              <div className="flex items-center gap-3 border-b border-white/10 px-4 py-3.5">
                <Tag size={16} className="shrink-0 text-white/40" />
                <input
                  value={form.hashtags}
                  onChange={e => updateField('hashtags', e.target.value)}
                  className="w-full bg-transparent text-[14px] text-white outline-none placeholder:text-white/35"
                  placeholder={isAd ? 'Add hashtags (comma-separated)' : 'Add tags'}
                />
              </div>

              {/* ── Ad-only fields ── */}
              {isAd && (
                <>
                  {/* ── STEP 3: CTA ── */}
                  <div className="px-4 pt-4 pb-1">
                    <div className="flex items-center gap-2 mb-3">
                      <div className="flex-1 h-px bg-white/10" />
                      <span className="text-[10px] font-bold text-indigo-400 uppercase tracking-widest whitespace-nowrap">Step 3 · Call-To-Action</span>
                      <div className="flex-1 h-px bg-white/10" />
                    </div>
                  </div>

                  <div className="px-4 pb-3 space-y-3">
                    {/* CTA type grid */}
                    <div className="grid grid-cols-3 gap-1.5">
                      {CTA_TYPES.map(ct => {
                        const Ico = ct.icon;
                        const active = form.ctaType === ct.value;
                        return (
                          <button
                            key={ct.value}
                            type="button"
                            onClick={() => updateField('ctaType', ct.value)}
                            className={`flex flex-col items-center gap-1 py-2.5 px-1 rounded-xl text-[10px] font-bold border transition-all ${
                              active
                                ? 'bg-indigo-600 text-white border-indigo-500'
                                : 'bg-white/5 text-white/50 border-white/10 hover:border-white/25'
                            }`}
                          >
                            <Ico size={14} />
                            {ct.label}
                          </button>
                        );
                      })}
                    </div>

                    {form.ctaType && (
                      <AccordionSection
                        icon={MousePointerClick}
                        title="CTA Details"
                        subtitle={`${CTA_TYPES.find(c => c.value === form.ctaType)?.label} settings`}
                        isOpen={openSection === 'cta'}
                        onToggle={() => toggleSection('cta')}
                        accentColor="indigo"
                      >
                        <FieldInput
                          label="Destination URL"
                          value={form.ctaUrl}
                          onChange={v => updateField('ctaUrl', v)}
                          placeholder="https://example.com"
                          type="url"
                          icon={Link2}
                        />
                        <FieldInput
                          label="Deep Link"
                          value={form.ctaDeepLink}
                          onChange={v => updateField('ctaDeepLink', v)}
                          placeholder="myapp://product/123"
                          icon={Link2}
                        />
                        <FieldInput
                          label="Phone Number"
                          value={form.ctaPhone}
                          onChange={v => updateField('ctaPhone', v)}
                          placeholder="+91 98765 43210"
                          type="tel"
                          icon={Phone}
                        />
                        <FieldInput
                          label="WhatsApp Number"
                          value={form.ctaWhatsapp}
                          onChange={v => updateField('ctaWhatsapp', v)}
                          placeholder="919876543210"
                          icon={Phone}
                        />
                        <FieldInput
                          label="Contact Email"
                          value={form.ctaEmail}
                          onChange={v => updateField('ctaEmail', v)}
                          placeholder="hello@company.com"
                          type="email"
                          icon={Mail}
                        />
                      </AccordionSection>
                    )}
                  </div>

                  {/* ── STEP 4: Audience Targeting ── */}
                  <div className="px-4 pt-2 pb-1">
                    <div className="flex items-center gap-2 mb-3">
                      <div className="flex-1 h-px bg-white/10" />
                      <span className="text-[10px] font-bold text-orange-400 uppercase tracking-widest whitespace-nowrap">Step 4 · Audience Targeting</span>
                      <div className="flex-1 h-px bg-white/10" />
                    </div>
                  </div>

                  <div className="px-4 pb-3 space-y-3">

                    {/* Age Range */}
                    <AccordionSection
                      icon={Users}
                      title="Age Range"
                      subtitle={`${form.ageMin} – ${form.ageMax} years`}
                      isOpen={openSection === 'age'}
                      onToggle={() => toggleSection('age')}
                      accentColor="purple"
                    >
                      <div className="grid grid-cols-2 gap-3">
                        <FieldInput
                          label="Min Age"
                          value={form.ageMin}
                          onChange={v => updateField('ageMin', v)}
                          placeholder="13"
                          type="number"
                        />
                        <FieldInput
                          label="Max Age"
                          value={form.ageMax}
                          onChange={v => updateField('ageMax', v)}
                          placeholder="65"
                          type="number"
                        />
                      </div>
                      {/* Age range slider visual */}
                      <div className="mt-2 flex items-center gap-2">
                        <span className="text-[10px] text-white/40">{form.ageMin || 13}</span>
                        <div className="relative flex-1 h-1.5 bg-white/10 rounded-full">
                          <div
                            className="absolute h-full rounded-full bg-purple-500"
                            style={{
                              left: `${Math.min(100, Math.max(0, ((Number(form.ageMin) - 13) / (65 - 13)) * 100))}%`,
                              right: `${Math.min(100, Math.max(0, (1 - (Number(form.ageMax) - 13) / (65 - 13)) * 100))}%`,
                            }}
                          />
                        </div>
                        <span className="text-[10px] text-white/40">{form.ageMax || 65}</span>
                      </div>
                    </AccordionSection>

                    {/* Gender */}
                    <AccordionSection
                      icon={Target}
                      title="Gender"
                      subtitle={GENDER_OPTIONS.find(g => g.value === form.gender)?.label || 'All'}
                      isOpen={openSection === 'gender'}
                      onToggle={() => toggleSection('gender')}
                      accentColor="pink"
                    >
                      <div className="grid grid-cols-4 gap-1.5">
                        {GENDER_OPTIONS.map(opt => (
                          <button
                            key={opt.value}
                            type="button"
                            onClick={() => updateField('gender', opt.value)}
                            className={`py-2 rounded-lg text-[11px] font-bold border transition-all ${
                              form.gender === opt.value
                                ? 'bg-pink-600 text-white border-pink-500'
                                : 'bg-white/5 text-white/50 border-white/10 hover:border-white/25'
                            }`}
                          >
                            {opt.label}
                          </button>
                        ))}
                      </div>
                    </AccordionSection>

                    {/* Countries */}
                    <AccordionSection
                      icon={Globe}
                      title="Target Countries"
                      subtitle={form.targetCountries.length ? `${form.targetCountries.length} selected` : 'Not set'}
                      isOpen={openSection === 'countries'}
                      onToggle={() => toggleSection('countries')}
                      accentColor="blue"
                    >
                      <div className="space-y-1.5">
                        <p className="text-[11px] text-white/40">Comma-separated country names</p>
                        <input
                          value={form.targetCountries.join(', ')}
                          onChange={e => updateField('targetCountries', splitList(e.target.value))}
                          placeholder="India, USA, UK"
                          className="w-full bg-white/8 border border-white/10 rounded-lg px-3 py-2.5 text-[13px] text-white placeholder:text-white/30 outline-none focus:border-white/30 transition-all"
                        />
                        {form.targetCountries.length > 0 && (
                          <div className="flex flex-wrap gap-1.5 pt-1">
                            {form.targetCountries.map((c, i) => (
                              <span
                                key={i}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-900/40 text-blue-300 text-[10px] font-semibold border border-blue-800/40"
                              >
                                {c}
                                <button type="button" onClick={() => updateField('targetCountries', form.targetCountries.filter((_, j) => j !== i))}>
                                  <X size={9} />
                                </button>
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </AccordionSection>

                    {/* States */}
                    <AccordionSection
                      icon={MapPin}
                      title="Target States / Regions"
                      subtitle={form.targetStatesList.length ? `${form.targetStatesList.length} selected` : 'Not set'}
                      isOpen={openSection === 'states'}
                      onToggle={() => toggleSection('states')}
                      accentColor="orange"
                    >
                      <div className="space-y-1.5">
                        <p className="text-[11px] text-white/40">Comma-separated state names</p>
                        <input
                          value={form.targetStatesList.join(', ')}
                          onChange={e => updateField('targetStatesList', splitList(e.target.value))}
                          placeholder="Karnataka, Maharashtra"
                          className="w-full bg-white/8 border border-white/10 rounded-lg px-3 py-2.5 text-[13px] text-white placeholder:text-white/30 outline-none focus:border-white/30 transition-all"
                        />
                        {form.targetStatesList.length > 0 && (
                          <div className="flex flex-wrap gap-1.5 pt-1">
                            {form.targetStatesList.map((s, i) => (
                              <span
                                key={i}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-orange-900/40 text-orange-300 text-[10px] font-semibold border border-orange-800/40"
                              >
                                {s}
                                <button type="button" onClick={() => updateField('targetStatesList', form.targetStatesList.filter((_, j) => j !== i))}>
                                  <X size={9} />
                                </button>
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </AccordionSection>

                    {/* Category */}
                    <div className="border border-white/10 rounded-xl overflow-hidden">
                      <div className="px-4 py-3 bg-white/5">
                        <p className="text-[11px] font-bold text-orange-400 uppercase tracking-wider mb-2">Category</p>
                        <input
                          value={form.category}
                          onChange={e => updateField('category', e.target.value)}
                          placeholder="e.g. Fashion, Electronics"
                          className="w-full bg-white/8 border border-white/10 rounded-lg px-3 py-2.5 text-[13px] text-white placeholder:text-white/30 outline-none focus:border-white/30 transition-all"
                        />
                      </div>
                    </div>

                    {/* Keywords */}
                    <div className="border border-white/10 rounded-xl overflow-hidden">
                      <div className="px-4 py-3 bg-white/5">
                        <p className="text-[11px] font-bold text-orange-400 uppercase tracking-wider mb-2">Keywords</p>
                        <div className="flex gap-2">
                          <input
                            value={keywordInput}
                            onChange={e => setKeywordInput(e.target.value)}
                            onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addKeyword(); } }}
                            placeholder="Add keyword & press Enter"
                            className="flex-1 bg-white/8 border border-white/10 rounded-lg px-3 py-2 text-[13px] text-white placeholder:text-white/30 outline-none focus:border-white/30 transition-all"
                          />
                          <button
                            type="button"
                            onClick={addKeyword}
                            className="px-3 py-2 rounded-lg bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold transition-colors"
                          >
                            +
                          </button>
                        </div>
                        {form.keywords.length > 0 && (
                          <div className="flex flex-wrap gap-1.5 mt-2">
                            {form.keywords.map((k, i) => (
                              <span
                                key={i}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-orange-900/40 text-orange-300 text-[10px] font-semibold border border-orange-800/40"
                              >
                                {k}
                                <button
                                  type="button"
                                  onClick={() => updateField('keywords', form.keywords.filter((_, j) => j !== i))}
                                >
                                  <X size={9} />
                                </button>
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Budget */}
                    <div className="border border-white/10 rounded-xl overflow-hidden">
                      <div className="px-4 py-3 bg-white/5">
                        <p className="text-[11px] font-bold text-orange-400 uppercase tracking-wider mb-2">Total Budget (Coins)</p>
                        <input
                          type="number"
                          value={form.totalBudgetCoins}
                          onChange={e => updateField('totalBudgetCoins', e.target.value)}
                          placeholder="e.g. 500"
                          className="w-full bg-white/8 border border-white/10 rounded-lg px-3 py-2.5 text-[13px] text-white placeholder:text-white/30 outline-none focus:border-white/30 transition-all"
                        />
                      </div>
                    </div>
                  </div>
                </>
              )}

              {/* ── Engagement controls ── */}
              <div className="border-t border-white/10 px-4 py-4">
                <ToggleRow
                  label={form.hideLikes ? 'Unhide like count to others' : 'Hide like count from others'}
                  checked={form.hideLikes}
                  onToggle={() => updateField('hideLikes', !form.hideLikes)}
                />
              </div>
              <div className="border-t border-white/10 px-4 py-4">
                <ToggleRow
                  label={isAd ? 'Disable comments' : form.disableComments ? 'Turn on commenting' : 'Turn off commenting'}
                  checked={form.disableComments}
                  onToggle={() => updateField('disableComments', !form.disableComments)}
                />
              </div>

              {error && (
                <div className="mx-4 mb-4 p-3 rounded-xl bg-red-900/30 border border-red-800/40 text-red-300 text-xs flex items-start gap-2">
                  <X size={13} className="mt-0.5 shrink-0" />
                  {error}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}