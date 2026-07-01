import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import api from '../../lib/api';
import { fetchMe } from '../../store/authSlice';
import {
  ArrowLeft, Camera, Loader2, Check, AlertCircle, CheckCircle2,
  Pencil, X, Mail, Phone, RefreshCw,
} from 'lucide-react';

const GENDER_OPTIONS = [
  { label: 'Male',             value: 'male' },
  { label: 'Female',           value: 'female' },
  { label: 'Third Gender',     value: 'third_gender' },
  { label: 'Prefer Not to Say', value: 'prefer_not_to_say' },
];

const EDIT_CLS = 'w-full px-3.5 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] placeholder-gray-400 dark:placeholder-gray-600 transition-all';
const VIEW_CLS = 'w-full px-3.5 py-2.5 rounded-xl text-sm text-gray-800 dark:text-gray-200 bg-gray-50 dark:bg-gray-800/50 border border-transparent cursor-default pointer-events-none select-text';

/* ── OTP 6-box input ──────────────────────────────────────────── */
const OtpInput = ({ value, onChange }) => {
  const inputs = useRef([]);
  const digits = value.split('').concat(Array(6).fill('')).slice(0, 6);

  const handleKey = (i, e) => {
    if (e.key === 'Backspace' && !digits[i] && i > 0) inputs.current[i - 1]?.focus();
  };
  const handleChange = (i, v) => {
    const d = v.replace(/\D/g, '').slice(-1);
    const next = [...digits]; next[i] = d;
    onChange(next.join(''));
    if (d && i < 5) inputs.current[i + 1]?.focus();
  };
  const handlePaste = (e) => {
    const p = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    onChange(p.padEnd(6, '').slice(0, 6));
    inputs.current[Math.min(p.length, 5)]?.focus();
  };

  return (
    <div className="flex gap-2 justify-center">
      {digits.map((d, i) => (
        <input key={i} ref={el => inputs.current[i] = el}
          type="text" inputMode="numeric" maxLength={1} value={d}
          onChange={e => handleChange(i, e.target.value)}
          onKeyDown={e => handleKey(i, e)} onPaste={handlePaste}
          className="w-10 h-11 text-center text-base font-bold rounded-xl border-2 border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-gray-900 dark:text-white focus:border-[#fa3f5e] focus:ring-2 focus:ring-[#fa3f5e]/20 outline-none transition-all" />
      ))}
    </div>
  );
};

/* ── Verify OTP modal ─────────────────────────────────────────── */
const VerifyModal = ({ type, onClose, onVerified }) => {
  const [step, setStep] = useState('sending'); // 'sending' | 'input' | 'done'
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [cooldown, setCooldown] = useState(0);

  const sendUrl    = type === 'email' ? '/settings/account/verify-email/send'   : '/settings/account/verify-phone/send';
  const confirmUrl = type === 'email' ? '/settings/account/verify-email/confirm' : '/settings/account/verify-phone/confirm';
  const label      = type === 'email' ? 'Email' : 'Phone';

  const handleSend = useCallback(async () => {
    setLoading(true); setError('');
    try {
      await api.post(sendUrl);
      setStep('input');
      setCooldown(60);
    } catch (e) {
      setError(e?.response?.data?.message || `Failed to send OTP. Try again.`);
      setStep('input');
    } finally { setLoading(false); }
  }, [sendUrl]);

  useEffect(() => { handleSend(); }, [handleSend]);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown(c => c - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  const handleConfirm = async () => {
    if (otp.length < 6) { setError('Enter all 6 digits.'); return; }
    setLoading(true); setError('');
    try {
      await api.post(confirmUrl, { otp });
      setStep('done');
      setTimeout(() => { onVerified(); onClose(); }, 1500);
    } catch (e) {
      setError(e?.response?.data?.message || 'Incorrect OTP. Try again.');
    } finally { setLoading(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-xs bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-5 relative">
        <button onClick={onClose} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 p-1">
          <X size={16} />
        </button>

        {/* Title */}
        <div className="flex items-center gap-2.5 mb-4">
          <div className="p-2 rounded-xl bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">
            {type === 'email' ? <Mail size={18} /> : <Phone size={18} />}
          </div>
          <div>
            <p className="font-bold text-sm text-gray-900 dark:text-white">Verify {label}</p>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {step === 'done' ? `${label} verified!` : `Enter the 6-digit code`}
            </p>
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-xs mb-3">
            <AlertCircle size={13} className="shrink-0" /> {error}
          </div>
        )}

        {/* Sending spinner */}
        {step === 'sending' && (
          <div className="flex flex-col items-center py-6 gap-3">
            <Loader2 size={24} className="animate-spin text-[#fa3f5e]" />
            <p className="text-sm text-gray-500 dark:text-gray-400">Sending OTP…</p>
          </div>
        )}

        {/* OTP input */}
        {step === 'input' && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 text-center mb-4">
              Code sent to your {type === 'email' ? 'email address' : 'mobile number'}. Valid for 10 minutes.
            </p>
            <div className="mb-4">
              <OtpInput value={otp} onChange={setOtp} />
            </div>
            <button onClick={handleConfirm} disabled={loading || otp.length < 6}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-2 mb-2">
              {loading ? <><Loader2 size={14} className="animate-spin" /> Verifying…</> : 'Verify'}
            </button>
            <button onClick={() => { setOtp(''); handleSend(); }} disabled={cooldown > 0 || loading}
              className="w-full py-2 rounded-xl border border-gray-200 dark:border-gray-700 text-xs text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-50 flex items-center justify-center gap-1.5 transition-colors">
              <RefreshCw size={12} /> {cooldown > 0 ? `Resend in ${cooldown}s` : 'Resend Code'}
            </button>
          </>
        )}

        {/* Success */}
        {step === 'done' && (
          <div className="flex flex-col items-center py-6 gap-3">
            <div className="w-14 h-14 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center">
              <CheckCircle2 size={28} className="text-green-500" />
            </div>
            <p className="font-bold text-gray-900 dark:text-white text-sm">{label} Verified!</p>
          </div>
        )}
      </div>
    </div>
  );
};

/* ── Layout helpers ───────────────────────────────────────────── */
const Field = ({ label, children }) => (
  <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-800 last:border-0">
    <label className="text-[11px] font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">{label}</label>
    <div className="mt-1.5">{children}</div>
  </div>  
);

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const VerifiedBadge = () => (
  <div className="flex-shrink-0 flex items-center gap-1 text-green-600 dark:text-green-400 text-xs font-bold">
    <CheckCircle2 size={14} /> Verified
  </div>
);

/* ── Main component ───────────────────────────────────────────── */
const AccountSettings = () => {
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;

  const [isEditing, setIsEditing] = useState(false);
  const snapshot = useRef(null);

  const [form, setForm] = useState({
    full_name: '', username: '', bio: '', website: '',
    date_of_birth: '', gender: '', location: '', email: '', phone: '',
  });
  const [avatarUrl, setAvatarUrl] = useState('');
  const [isEmailVerified, setIsEmailVerified] = useState(false);
  const [isPhoneVerified, setIsPhoneVerified] = useState(false);
  const [verifyTarget, setVerifyTarget] = useState(null); // 'email' | 'phone'

  const [interests, setInterests] = useState([]);
  const [allInterests, setAllInterests] = useState([]);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const fileInputRef = useRef(null);
  const upd = (key, val) => setForm(p => ({ ...p, [key]: val }));
  const ic = isEditing ? EDIT_CLS : VIEW_CLS;

  useEffect(() => {
    if (!userId) return;
    Promise.allSettled([
      api.get(`/users/${userId}`),
      api.get(`/users/${userId}/interests`),
    ]).then(([userRes, interestsRes]) => {
      let loadedForm = {
        full_name: '', username: '', bio: '', website: '',
        date_of_birth: '', gender: '', location: '', email: '', phone: '',
      };
      let loadedAvatar = '';

      if (userRes.status === 'fulfilled') {
        const u = userRes.value.data?.user || userRes.value.data;
        loadedForm = {
          full_name: u.full_name || '',
          username: u.username || '',
          bio: u.bio || '',
          website: u.website || '',
          date_of_birth: u.date_of_birth ? u.date_of_birth.slice(0, 10) : '',
          gender: u.gender || '',
          location: u.location || '',
          email: u.email || '',
          phone: u.phone || u.mobile_number || '',
        };
        loadedAvatar = u.avatar_url || '';
        setIsEmailVerified(!!u.is_email_verified);
        setIsPhoneVerified(!!u.is_phone_verified);
      } else if (userObject) {
        loadedForm = {
          full_name: userObject.full_name || '', username: userObject.username || '',
          bio: userObject.bio || '', website: userObject.website || '',
          date_of_birth: userObject.date_of_birth ? userObject.date_of_birth.slice(0, 10) : '',
          gender: userObject.gender || '', location: userObject.location || '',
          email: userObject.email || '',
          phone: userObject.phone || userObject.mobile_number || '',
        };
        loadedAvatar = userObject.avatar_url || '';
        setIsEmailVerified(!!userObject.is_email_verified);
        setIsPhoneVerified(!!userObject.is_phone_verified);
      }

      setForm(loadedForm);
      setAvatarUrl(loadedAvatar);
      snapshot.current = { form: loadedForm, avatarUrl: loadedAvatar };

      if (interestsRes.status === 'fulfilled') {
        const d = interestsRes.value.data;
        setInterests(d.interests || d.user_interests || []);
        setAllInterests(d.all_interests || d.available_interests || []);
      }
    }).finally(() => setLoading(false));
  }, [userId]);

  const handleCancel = () => {
    if (snapshot.current) {
      setForm(snapshot.current.form);
      setAvatarUrl(snapshot.current.avatarUrl);
    }
    setIsEditing(false);
    setError('');
  };

  const handleAvatarUpload = async (file) => {
    if (!file || !isEditing) return;
    setAvatarUploading(true);
    try {
      const fd = new FormData();
      fd.append('file', file);
      const res = await api.post('/upload/avatar', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setAvatarUrl(res.data?.avatar_url || res.data?.fileUrl || '');
    } catch { setError('Failed to upload photo. Try again.'); }
    finally { setAvatarUploading(false); }
  };

  const handleSave = async () => {
    setSaving(true); setError('');
    try {
      await api.put(`/users/${userId}`, { ...form, avatar_url: avatarUrl });
      await dispatch(fetchMe());
      snapshot.current = { form: { ...form }, avatarUrl };
      setSaved(true);
      setIsEditing(false);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to save. Try again.');
    } finally { setSaving(false); }
  };

  const toggleInterest = async (name) => {
    if (!isEditing) return;
    const isOn = interests.includes(name);
    const next = isOn ? interests.filter(i => i !== name) : [...interests, name];
    setInterests(next);
    try { await api.put(`/users/${userId}/interests`, { interests: next }); }
    catch { setInterests(interests); }
  };

  const initials = (form.full_name || form.username || 'U').slice(0, 1).toUpperCase();

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">
      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></Link>
        <h1 className="text-base font-semibold dark:text-white">Account</h1>

        {!isEditing ? (
          <button onClick={() => setIsEditing(true)}
            className="flex items-center gap-1.5 px-4 py-1.5 rounded-full border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-300 text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
            <Pencil size={13} /> Edit
          </button>
        ) : (
          <div className="flex items-center gap-2">
            <button onClick={handleCancel}
              className="flex items-center gap-1 px-3 py-1.5 rounded-full border border-gray-300 dark:border-gray-700 text-gray-600 dark:text-gray-400 text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
              <X size={13} /> Cancel
            </button>
            <button onClick={handleSave} disabled={saving}
              className="flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#fa3f5e] text-white text-sm font-bold disabled:opacity-60 transition-opacity min-w-[68px] justify-center">
              {saving ? <Loader2 size={13} className="animate-spin" /> : saved ? <Check size={13} /> : null}
              {saving ? 'Saving…' : saved ? 'Saved!' : 'Save'}
            </button>
          </div>
        )}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-24">
          <Loader2 size={28} className="animate-spin text-gray-300 dark:text-gray-600" />
        </div>
      ) : (
        <div className="max-w-2xl mx-auto px-4 pt-6 space-y-5">

          {/* Avatar */}
          <div className="flex flex-col items-center gap-2 pb-2">
            <div className="relative">
              <div className="w-[90px] h-[90px] rounded-full overflow-hidden bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 ring-4 ring-white dark:ring-gray-900 shadow-lg">
                {avatarUrl
                  ? <img src={avatarUrl} alt="Avatar" className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-gray-500 dark:text-gray-300">{initials}</div>
                }
              </div>
              {isEditing && (
                <button onClick={() => fileInputRef.current?.click()} disabled={avatarUploading}
                  className="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-[#fa3f5e] text-white flex items-center justify-center shadow-md border-2 border-white dark:border-gray-900">
                  {avatarUploading ? <Loader2 size={13} className="animate-spin" /> : <Camera size={13} />}
                </button>
              )}
              <input ref={fileInputRef} type="file" accept="image/*" className="hidden"
                onChange={e => { if (e.target.files?.[0]) handleAvatarUpload(e.target.files[0]); e.target.value = ''; }} />
            </div>
            {isEditing ? (
              <button onClick={() => fileInputRef.current?.click()} className="text-[#fa3f5e] text-sm font-semibold">
                Change Profile Photo
              </button>
            ) : (
              <p className="text-sm font-semibold text-gray-700 dark:text-gray-300">{form.full_name || form.username || 'Your Profile'}</p>
            )}
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
              <AlertCircle size={14} className="shrink-0" /> {error}
            </div>
          )}

          {/* ── Personal Information ──────────────────────── */}
          <div>
            <SectionTitle title="Personal Information" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

              <Field label="Full Name">
                <input className={ic} placeholder="Your full name" readOnly={!isEditing}
                  value={form.full_name} onChange={e => upd('full_name', e.target.value)} />
              </Field>

              <Field label="Username">
                <div className="relative">
                  <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm font-medium">@</span>
                  <input className={`${ic} pl-7`} placeholder="username" readOnly={!isEditing}
                    value={form.username} onChange={e => upd('username', e.target.value)} />
                </div>
              </Field>

              <Field label="Bio">
                <textarea className={`${ic} resize-none`} rows={3}
                  placeholder="Write something about yourself…" maxLength={200}
                  readOnly={!isEditing}
                  value={form.bio} onChange={e => upd('bio', e.target.value)} />
                {isEditing && <p className="text-[11px] text-gray-400 text-right mt-1">{form.bio.length}/200</p>}
              </Field>

              <Field label="Website">
                <input className={ic} placeholder="https://yourwebsite.com" type="url" readOnly={!isEditing}
                  value={form.website} onChange={e => upd('website', e.target.value)} />
              </Field>

              <Field label="Date of Birth">
                {isEditing ? (
                  <input className={ic} type="date"
                    value={form.date_of_birth} onChange={e => upd('date_of_birth', e.target.value)} />
                ) : (
                  <input className={ic} type="text" readOnly
                    value={form.date_of_birth
                      ? new Date(form.date_of_birth + 'T00:00:00').toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
                      : '—'} />
                )}
              </Field>

              <Field label="Gender">
                <div className="grid grid-cols-2 gap-2">
                  {GENDER_OPTIONS.map(({ label, value }) => (
                    <button key={value}
                      onClick={() => isEditing && upd('gender', form.gender === value ? '' : value)}
                      className={`flex items-center gap-2 px-3 py-2.5 rounded-xl text-sm font-medium border transition-all text-left ${
                        form.gender === value
                          ? 'bg-[#fa3f5e]/10 border-[#fa3f5e] text-[#fa3f5e]'
                          : isEditing
                          ? 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800'
                          : 'border-gray-100 dark:border-gray-800 text-gray-400 dark:text-gray-600 cursor-default'
                      }`}>
                      <span className={`w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0 ${form.gender === value ? 'border-[#fa3f5e]' : 'border-gray-300 dark:border-gray-600'}`}>
                        {form.gender === value && <span className="w-2 h-2 rounded-full bg-[#fa3f5e]" />}
                      </span>
                      {label}
                    </button>
                  ))}
                </div>
              </Field>

              <Field label="Location">
                <input className={ic} placeholder="City, Country" readOnly={!isEditing}
                  value={form.location} onChange={e => upd('location', e.target.value)} />
              </Field>
            </div>
          </div>

          {/* ── Interests ─────────────────────────────────── */}
          <div>
            <SectionTitle title="Interests" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm p-4">
              {(allInterests.length === 0 && interests.length === 0) ? (
                <p className="text-sm text-gray-400 dark:text-gray-500 text-center py-4">No interests found.</p>
              ) : (
                <>
                  {isEditing && <p className="text-xs text-gray-400 dark:text-gray-500 mb-3">Tap to select or remove interests</p>}
                  <div className="flex flex-wrap gap-2">
                    {(allInterests.length > 0 ? allInterests : interests).map((item) => {
                      const name = typeof item === 'string' ? item : (item.name || item.category || '');
                      const isOn = interests.some(i => (typeof i === 'string' ? i : i.name || i.category || '') === name);
                      return (
                        <button key={name} onClick={() => toggleInterest(name)}
                          className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-all ${
                            isOn
                              ? 'bg-[#fa3f5e] text-white border-[#fa3f5e] shadow-sm'
                              : isEditing
                              ? 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-[#fa3f5e] hover:text-[#fa3f5e]'
                              : 'border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500 cursor-default'
                          }`}>
                          {name}
                        </button>
                      );
                    })}
                  </div>
                </>
              )}
            </div>
          </div>

          {/* ── Contact Information ───────────────────────── */}
          <div>
            <SectionTitle title="Contact Information" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

              {/* Email */}
              <Field label="Email Address">
                <div className="flex items-center gap-2">
                  <input className={`${ic} flex-1`} placeholder="you@example.com" type="email" readOnly={!isEditing}
                    value={form.email} onChange={e => upd('email', e.target.value)} />
                  {isEmailVerified ? (
                    <VerifiedBadge />
                  ) : (
                    <button onClick={() => setVerifyTarget('email')}
                      className="flex-shrink-0 px-3 py-2 rounded-xl border border-[#fa3f5e]/30 bg-[#fa3f5e]/5 text-xs font-bold text-[#fa3f5e] hover:bg-[#fa3f5e]/10 transition-colors whitespace-nowrap">
                      Verify
                    </button>
                  )}
                </div>
                {!isEmailVerified && (
                  <p className="text-[11px] text-amber-500 dark:text-amber-400 mt-1.5 flex items-center gap-1">
                    <AlertCircle size={11} /> Email not verified
                  </p>
                )}
              </Field>

              {/* Mobile */}
              <Field label="Mobile Number">
                <div className="flex items-center gap-2">
                  <input className={`${ic} flex-1`} placeholder="+91 98765 43210" type="tel" readOnly={!isEditing}
                    value={form.phone} onChange={e => upd('phone', e.target.value)} />
                  {isPhoneVerified ? (
                    <VerifiedBadge />
                  ) : (
                    <button onClick={() => setVerifyTarget('phone')}
                      className="flex-shrink-0 px-3 py-2 rounded-xl border border-[#fa3f5e]/30 bg-[#fa3f5e]/5 text-xs font-bold text-[#fa3f5e] hover:bg-[#fa3f5e]/10 transition-colors whitespace-nowrap">
                      Verify
                    </button>
                  )}
                </div>
                {!isPhoneVerified && (
                  <p className="text-[11px] text-amber-500 dark:text-amber-400 mt-1.5 flex items-center gap-1">
                    <AlertCircle size={11} /> Mobile not verified
                  </p>
                )}
              </Field>
            </div>
          </div>

          {/* Save Button — only when editing */}
          {isEditing && (
            <button onClick={handleSave} disabled={saving}
              className="w-full py-3.5 rounded-2xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60 shadow-lg shadow-[#fa3f5e]/20">
              {saving
                ? <><Loader2 size={16} className="animate-spin" /> Saving…</>
                : saved
                ? <><CheckCircle2 size={16} /> Changes Saved!</>
                : 'Save Changes'
              }
            </button>
          )}

        </div>
      )}

      {/* Verify OTP Modal */}
      {verifyTarget && (
        <VerifyModal
          type={verifyTarget}
          onClose={() => setVerifyTarget(null)}
          onVerified={() => {
            if (verifyTarget === 'email') setIsEmailVerified(true);
            else setIsPhoneVerified(true);
            setVerifyTarget(null);
          }}
        />
      )}
    </div>
  );
};

export default AccountSettings;
