import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import api from '../../lib/api';
import { fetchMe, logoutUser } from '../../store/authSlice';
import {
  ArrowLeft, Lock, ShieldCheck, KeyRound, Mail, Eye, EyeOff,
  CheckCircle2, AlertCircle, X, RefreshCw, Smartphone, Loader2,
  ChevronRight, Monitor, Clock, LogOut, Trash2, MessageSquare, Pencil, Check,
} from 'lucide-react';

const BASE = 'https://api.bebsmart.in';

/* ───────────────────────── shared helpers ──────────────────── */
const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const PasswordInput = ({ value, onChange, placeholder }) => {
  const [show, setShow] = useState(false);
  return (
    <div className="relative">
      <input type={show ? 'text' : 'password'} value={value} onChange={onChange} placeholder={placeholder}
        className="w-full px-4 py-2.5 pr-10 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] placeholder-gray-400 dark:placeholder-gray-600 transition-all" />
      <button type="button" onClick={() => setShow(v => !v)}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
        {show ? <EyeOff size={15} /> : <Eye size={15} />}
      </button>
    </div>
  );
};

const OtpInput = ({ value, onChange, length = 6 }) => {
  const inputs = useRef([]);
  const digits = value.split('').concat(Array(length).fill('')).slice(0, length);
  const handleKey = (i, e) => { if (e.key === 'Backspace' && !digits[i] && i > 0) inputs.current[i - 1]?.focus(); };
  const handleChange = (i, v) => {
    const d = v.replace(/\D/g, '').slice(-1);
    const next = [...digits]; next[i] = d;
    onChange(next.join(''));
    if (d && i < length - 1) inputs.current[i + 1]?.focus();
  };
  const handlePaste = (e) => {
    const p = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, length);
    onChange(p.padEnd(length, '').slice(0, length));
    inputs.current[Math.min(p.length, length - 1)]?.focus();
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

const AlertBanner = ({ type, msg }) => {
  if (!msg) return null;
  return (
    <div className={`flex items-center gap-2 px-3 py-2.5 rounded-xl text-sm font-medium mb-4 border ${
      type === 'success'
        ? 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-700 dark:text-green-400'
        : 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-600 dark:text-red-400'
    }`}>
      {type === 'success' ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />} {msg}
    </div>
  );
};

/* ───────────────────────── 2FA modal ───────────────────────── */
const TwoFAModal = ({ mode, method, email, phone, userId, onClose, onDone }) => {
  const isSms = method === 'sms';
  const [step, setStep] = useState(1);
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown > 0) {
      const t = setTimeout(() => setCooldown(c => c - 1), 1000);
      return () => clearTimeout(t);
    }
  }, [cooldown]);

  const sendOtp = async () => {
    setError(''); setLoading(true);
    try {
      const token = localStorage.getItem('token');
      const endpoint = isSms ? `${BASE}/api/sms/send-otp` : `${BASE}/api/email/send-otp`;
      const body = isSms
        ? { phone, purpose: 'two_factor' }
        : { email, purpose: 'two_factor' };
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify(body),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || 'Failed to send OTP');
      setStep(2); setCooldown(60);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  const verifyOtp = async () => {
    if (otp.length < 6) { setError('Enter all 6 digits.'); return; }
    setError(''); setLoading(true);
    try {
      const token = localStorage.getItem('token');
      const endpoint = isSms ? `${BASE}/api/sms/verify-otp` : `${BASE}/api/email/verify-otp`;
      const body = isSms
        ? { phone, otp, purpose: 'two_factor' }
        : { email, otp, purpose: 'two_factor' };
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify(body),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || 'Invalid OTP');
      await api.put(`/users/${userId}`, { twoFA: { enabled: mode === 'enable', method } }, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });
      setSuccess(mode === 'enable' ? '2FA enabled!' : '2FA disabled!');
      setTimeout(() => onDone(mode === 'enable'), 1400);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  const maskedTarget = isSms
    ? (phone ? phone.slice(0, -4).replace(/\d/g, '•') + phone.slice(-4) : 'your phone')
    : email;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-xs bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-5 relative">
        <button onClick={onClose} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 p-1"><X size={16} /></button>
        <div className="flex items-center gap-2.5 mb-4">
          <div className={`p-2 rounded-xl ${mode === 'enable' ? 'bg-green-50 dark:bg-green-900/20 text-green-600' : 'bg-red-50 dark:bg-red-900/20 text-red-500'}`}>
            {isSms ? <MessageSquare size={18} /> : <ShieldCheck size={18} />}
          </div>
          <div>
            <p className="font-bold text-sm text-gray-900 dark:text-white">{mode === 'enable' ? 'Enable 2FA' : 'Disable 2FA'}</p>
            <p className="text-xs text-gray-500">{isSms ? 'via SMS' : 'via Email'} · {maskedTarget}</p>
          </div>
        </div>
        <AlertBanner type="success" msg={success} />
        <AlertBanner type="error" msg={error} />
        {step === 1 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">
              {mode === 'enable'
                ? `A verification code will be sent to your ${isSms ? 'phone number' : 'email'} to confirm enabling 2FA.`
                : `Verify your identity via ${isSms ? 'SMS' : 'email'} before disabling 2FA.`}
            </p>
            <button onClick={sendOtp} disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-2">
              {loading
                ? <><Loader2 size={14} className="animate-spin" /> Sending…</>
                : isSms ? <><MessageSquare size={14} /> Send SMS Code</> : <><Mail size={14} /> Send Email Code</>}
            </button>
          </>
        )}
        {step === 2 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-4 text-center">
              Enter the 6-digit code sent to your {isSms ? 'phone' : 'email'}
            </p>
            <div className="mb-4"><OtpInput value={otp} onChange={setOtp} /></div>
            <button onClick={verifyOtp} disabled={loading || otp.length < 6}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-2 mb-2">
              {loading ? <><Loader2 size={14} className="animate-spin" /> Verifying…</> : 'Verify & Confirm'}
            </button>
            <button onClick={() => { setOtp(''); sendOtp(); }} disabled={cooldown > 0 || loading}
              className="w-full py-2 rounded-xl border border-gray-200 dark:border-gray-800 text-xs text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-50 flex items-center justify-center gap-1.5">
              <RefreshCw size={12} /> {cooldown > 0 ? `Resend in ${cooldown}s` : 'Resend Code'}
            </button>
          </>
        )}
      </div>
    </div>
  );
};

/* ───────────────────────── reset password modal ─────────────── */
const ResetPasswordModal = ({ email, onClose }) => {
  const [step, setStep] = useState(1);
  const [token, setToken] = useState('');
  const [newPass, setNewPass] = useState('');
  const [confirmPass, setConfirmPass] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const sendLink = async () => {
    setError(''); setLoading(true);
    try {
      const res = await fetch(`${BASE}/api/email/forgot-password`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || 'Failed to send reset link');
      setStep(2);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  const doReset = async () => {
    if (!token.trim()) { setError('Please enter the reset token.'); return; }
    if (newPass.length < 6) { setError('Password must be at least 6 characters.'); return; }
    if (newPass !== confirmPass) { setError('Passwords do not match.'); return; }
    setError(''); setLoading(true);
    try {
      const res = await fetch(`${BASE}/api/email/reset-password`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, newPassword: newPass }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || 'Failed to reset password');
      setStep(3);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-xs bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-5 relative">
        <button onClick={onClose} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600 p-1"><X size={16} /></button>
        <div className="flex items-center gap-2.5 mb-4">
          <div className="p-2 rounded-xl bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]"><KeyRound size={18} /></div>
          <div>
            <p className="font-bold text-sm text-gray-900 dark:text-white">Reset Password</p>
            <p className="text-xs text-gray-500">via email link</p>
          </div>
        </div>
        <AlertBanner type="error" msg={error} />
        {step === 1 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">A reset link will be sent to:</p>
            <div className="px-3 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 text-xs font-semibold text-gray-800 dark:text-white mb-4 break-all">{email}</div>
            <button onClick={sendLink} disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-2">
              {loading ? <><Loader2 size={14} className="animate-spin" /> Sending…</> : <><Mail size={14} /> Send Reset Link</>}
            </button>
          </>
        )}
        {step === 2 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">Check your email for the reset token, paste it below and set a new password.</p>
            <div className="space-y-2.5 mb-4">
              <input type="text" value={token} onChange={e => setToken(e.target.value)} placeholder="Paste reset token"
                className="w-full px-3 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] placeholder-gray-400 text-gray-900 dark:text-white" />
              <PasswordInput value={newPass} onChange={e => setNewPass(e.target.value)} placeholder="New Password" />
              <PasswordInput value={confirmPass} onChange={e => setConfirmPass(e.target.value)} placeholder="Confirm New Password" />
            </div>
            <button onClick={doReset} disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-2">
              {loading ? <><Loader2 size={14} className="animate-spin" /> Resetting…</> : 'Reset Password'}
            </button>
          </>
        )}
        {step === 3 && (
          <div className="text-center py-3">
            <div className="w-12 h-12 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center mx-auto mb-3">
              <CheckCircle2 className="w-6 h-6 text-green-500" />
            </div>
            <p className="font-bold text-gray-900 dark:text-white text-sm mb-1">Password Reset!</p>
            <p className="text-xs text-gray-500 mb-4">Your password has been updated successfully.</p>
            <button onClick={onClose} className="px-5 py-2 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90">Done</button>
          </div>
        )}
      </div>
    </div>
  );
};

/* ───────────────────────── confirm modal ───────────────────── */
const ConfirmModal = ({ title, message, confirmLabel, confirmClass, onConfirm, onClose, loading }) => (
  <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
    <div className="w-full max-w-xs bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-5">
      <h3 className="font-bold text-gray-900 dark:text-white text-sm mb-2">{title}</h3>
      <p className="text-xs text-gray-500 dark:text-gray-400 mb-5">{message}</p>
      <div className="flex gap-2">
        <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-bold text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800">
          Cancel
        </button>
        <button onClick={onConfirm} disabled={loading}
          className={`flex-1 py-2.5 rounded-xl text-white text-sm font-bold hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-1.5 ${confirmClass}`}>
          {loading ? <Loader2 size={13} className="animate-spin" /> : null} {confirmLabel}
        </button>
      </div>
    </div>
  </div>
);

/* ───────────────────────── main ────────────────────────────── */
const SecuritySettings = () => {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);
  const userEmail = userObject?.email || '';
  const userPhone = userObject?.phone || userObject?.phone_number || userObject?.mobile || '';
  const userId = userObject?._id || userObject?.id;

  const [isEditing, setIsEditing] = useState(false);
  const savedMethod = useRef('email');

  // 2FA state
  const [twoFAEnabled, setTwoFAEnabled] = useState(false);
  const [twoFAMethod, setTwoFAMethod] = useState('email'); // 'email' | 'sms'
  const [twoFAModal, setTwoFAModal] = useState(null);

  // Password
  const [showChangePwd, setShowChangePwd] = useState(false);
  const [passwords, setPasswords] = useState({ current: '', newPass: '', confirm: '' });
  const [pwdLoading, setPwdLoading] = useState(false);
  const [pwdSuccess, setPwdSuccess] = useState('');
  const [pwdError, setPwdError] = useState('');
  const [showReset, setShowReset] = useState(false);

  // Login activity
  const [sessions, setSessions] = useState([]);
  const [loginHistory, setLoginHistory] = useState([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [showActivity, setShowActivity] = useState(false);
  const [showHistory, setShowHistory] = useState(false);

  // Confirm dialogs
  const [confirmLogoutAll, setConfirmLogoutAll] = useState(false);
  const [logoutAllLoading, setLogoutAllLoading] = useState(false);

  const [toast, setToast] = useState(null);
  const showToast = (msg, type = 'success') => { setToast({ msg, type }); setTimeout(() => setToast(null), 3000); };

  useEffect(() => {
    api.get('/auth/me').then(res => {
      setTwoFAEnabled(!!res.data?.twoFA?.enabled);
      const m = res.data?.twoFA?.method || 'email';
      setTwoFAMethod(m);
      savedMethod.current = m;
    }).catch(() => {});
  }, []);

  const handleCancelEdit = () => {
    setTwoFAMethod(savedMethod.current);
    setIsEditing(false);
  };

  const handleSaveEdit = async () => {
    try {
      await api.put(`/users/${userId}`, { twoFA: { method: twoFAMethod } });
      savedMethod.current = twoFAMethod;
      showToast('Security settings saved.');
    } catch { showToast('Failed to save settings.', 'error'); }
    setIsEditing(false);
  };

  const loadSessions = async () => {
    if (showActivity) { setShowActivity(false); return; }
    setShowActivity(true); setSessionsLoading(true);
    try {
      const res = await api.get('/auth/sessions');
      setSessions(res.data?.sessions || res.data || []);
    } catch { setSessions([]); }
    finally { setSessionsLoading(false); }
  };

  const loadHistory = async () => {
    if (showHistory) { setShowHistory(false); return; }
    setShowHistory(true);
    try {
      const res = await api.get('/auth/login-history');
      setLoginHistory(res.data?.history || res.data || []);
    } catch { setLoginHistory([]); }
  };

  const handleChangePassword = async () => {
    setPwdError(''); setPwdSuccess('');
    if (!passwords.current.trim()) { setPwdError('Current password is required.'); return; }
    if (passwords.newPass.length < 6) { setPwdError('New password must be at least 6 characters.'); return; }
    if (passwords.newPass !== passwords.confirm) { setPwdError('Passwords do not match.'); return; }
    setPwdLoading(true);
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE}/api/auth/change-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify({ currentPassword: passwords.current, newPassword: passwords.newPass, user_id: userId }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        setPwdSuccess('Password updated!');
        setPasswords({ current: '', newPass: '', confirm: '' });
        setTimeout(() => setPwdSuccess(''), 4000);
      } else {
        setPwdError(data?.message || data?.error || 'Failed to update password.');
      }
    } catch { setPwdError('Network error.'); }
    finally { setPwdLoading(false); }
  };

  const handleLogoutAllDevices = async () => {
    setLogoutAllLoading(true);
    try {
      await api.post('/auth/logout-all');
      setConfirmLogoutAll(false);
      showToast('Logged out from all other devices.');
      // reload sessions list to reflect changes
      setShowActivity(false);
      setSessions([]);
    } catch {
      showToast('Failed to logout from all devices.', 'error');
      setConfirmLogoutAll(false);
    } finally { setLogoutAllLoading(false); }
  };

  const handleRemoveSession = async (sessionId) => {
    try {
      await api.delete(`/auth/sessions/${sessionId}`);
      setSessions(prev => prev.filter(s => (s._id || s.id) !== sessionId));
      showToast('Session removed.');
    } catch {
      showToast('Failed to remove session.', 'error');
    }
  };

  const handleLogoutCurrent = () => {
    dispatch(logoutUser());
    navigate('/login');
  };

  const formatDate = (d) => {
    if (!d) return '—';
    const date = new Date(d);
    return date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  };

  const strengthLabel = (len) => {
    if (len < 4) return ['Weak', 1];
    if (len < 7) return ['Fair', 2];
    if (len < 10) return ['Good', 3];
    return ['Strong', 4];
  };

  const [strengthText, strengthLevel] = strengthLabel(passwords.newPass.length);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24">
      {/* Toast */}
      {toast && (
        <div className={`fixed top-20 right-4 z-[80] rounded-xl border px-4 py-3 text-sm font-semibold shadow-lg ${
          toast.type === 'success'
            ? 'border-green-200 bg-green-50 text-green-700 dark:border-green-800 dark:bg-green-900/20 dark:text-green-400'
            : 'border-red-200 bg-red-50 text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400'
        }`}>{toast.msg}</div>
      )}

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></Link>
        <h1 className="text-base font-semibold dark:text-white">Security</h1>

        {!isEditing ? (
          <button onClick={() => setIsEditing(true)}
            className="flex items-center gap-1.5 px-4 py-1.5 rounded-full border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-300 text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
            <Pencil size={13} /> Edit
          </button>
        ) : (
          <div className="flex items-center gap-2">
            <button onClick={handleCancelEdit}
              className="flex items-center gap-1 px-3 py-1.5 rounded-full border border-gray-300 dark:border-gray-700 text-gray-600 dark:text-gray-400 text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
              <X size={13} /> Cancel
            </button>
            <button onClick={handleSaveEdit}
              className="flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#fa3f5e] text-white text-sm font-bold min-w-[60px] justify-center">
              <Check size={13} /> Save
            </button>
          </div>
        )}
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {isEditing && (
          <div className="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-[#fa3f5e]/8 border border-[#fa3f5e]/20 text-[#fa3f5e] text-xs font-semibold">
            <Pencil size={12} /> Editing — tap Save when you're done
          </div>
        )}

        {/* ── Password ───────────────────────────────────── */}
        <div>
          <SectionTitle title="Password" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* Change Password accordion */}
            <button onClick={() => setShowChangePwd(v => !v)}
              className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
                  <Lock size={18} />
                </div>
                <div className="text-left">
                  <p className="font-medium text-gray-900 dark:text-white text-sm">Change Password</p>
                  <p className="text-xs text-gray-500">Update your current password</p>
                </div>
              </div>
              <ChevronRight size={16} className={`text-gray-400 transition-transform ${showChangePwd ? 'rotate-90' : ''}`} />
            </button>

            {showChangePwd && (
              <div className="px-4 pb-4 pt-3 space-y-3 border-t border-gray-100 dark:border-gray-800">
                <AlertBanner type="success" msg={pwdSuccess} />
                <AlertBanner type="error" msg={pwdError} />
                <PasswordInput value={passwords.current} onChange={e => setPasswords(p => ({ ...p, current: e.target.value }))} placeholder="Current Password" />
                <PasswordInput value={passwords.newPass} onChange={e => setPasswords(p => ({ ...p, newPass: e.target.value }))} placeholder="New Password" />
                <PasswordInput value={passwords.confirm} onChange={e => setPasswords(p => ({ ...p, confirm: e.target.value }))} placeholder="Confirm New Password" />
                {passwords.newPass && (
                  <div className="flex items-center gap-1.5">
                    {[1, 2, 3, 4].map(i => (
                      <div key={i} className={`flex-1 h-1 rounded-full transition-colors ${
                        strengthLevel >= i
                          ? i <= 1 ? 'bg-red-400' : i <= 2 ? 'bg-orange-400' : i <= 3 ? 'bg-yellow-400' : 'bg-green-500'
                          : 'bg-gray-200 dark:bg-gray-700'
                      }`} />
                    ))}
                    <span className="text-[10px] text-gray-400 whitespace-nowrap ml-1">{strengthText}</span>
                  </div>
                )}
                <button onClick={handleChangePassword} disabled={pwdLoading}
                  className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 flex items-center justify-center gap-2">
                  {pwdLoading ? <><Loader2 size={14} className="animate-spin" /> Updating…</> : 'Update Password'}
                </button>
              </div>
            )}

            {/* Reset password row */}
            <div className="border-t border-gray-100 dark:border-gray-800">
              <button onClick={() => setShowReset(true)}
                className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
                    <KeyRound size={18} />
                  </div>
                  <div className="text-left">
                    <p className="font-medium text-gray-900 dark:text-white text-sm">Reset Password</p>
                    <p className="text-xs text-gray-500">Send a reset link to your email</p>
                  </div>
                </div>
                <ChevronRight size={16} className="text-gray-400" />
              </button>
            </div>
          </div>
        </div>

        {/* ── Login Security (2FA) ───────────────────────── */}
        <div>
          <SectionTitle title="Login Security" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* 2FA toggle */}
            <div className="flex items-center gap-3 px-4 py-3.5 border-b border-gray-100 dark:border-gray-800">
              <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e] flex-shrink-0">
                <ShieldCheck size={18} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-gray-900 dark:text-white text-sm">Two-Factor Authentication</p>
                <p className="text-xs text-gray-500">Require a code at every login</p>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${twoFAEnabled ? 'bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400' : 'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400'}`}>
                  {twoFAEnabled ? 'ON' : 'OFF'}
                </span>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" checked={twoFAEnabled} onChange={() => setTwoFAModal(twoFAEnabled ? 'disable' : 'enable')} className="sr-only peer" />
                  <div className="w-10 h-5 rounded-full bg-gray-300 dark:bg-gray-700 peer-checked:bg-[#fa3f5e] transition-colors" />
                  <div className="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow transform transition-transform peer-checked:translate-x-5" />
                </label>
              </div>
            </div>

            {/* 2FA method selection */}
            <div className="px-4 py-3 space-y-2">
              <p className={`text-[11px] font-bold uppercase tracking-widest mb-2 ${isEditing ? 'text-[#fa3f5e]' : 'text-gray-400 dark:text-gray-500'}`}>
                Authentication Method {!isEditing && <span className="normal-case font-normal text-gray-400">— tap Edit to change</span>}
              </p>

              {[
                { key: 'email', label: 'Email OTP', sublabel: `Code sent to ${userEmail || 'your email'}`, icon: Mail, available: true },
                { key: 'sms', label: 'SMS OTP', sublabel: userPhone ? `Code sent to ${userPhone.slice(0, -4).replace(/\d/g, '•')}${userPhone.slice(-4)}` : 'No phone number added', icon: MessageSquare, available: !!userPhone },
                { key: 'app', label: 'Authenticator App', sublabel: 'Coming soon — Google/Microsoft Authenticator', icon: Smartphone, available: false },
              ].map(({ key, label, sublabel, icon: Icon, available }) => (
                <button key={key} disabled={!available || !twoFAEnabled || !isEditing}
                  onClick={() => available && twoFAEnabled && isEditing && setTwoFAMethod(key)}
                  className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border transition-all ${
                    twoFAMethod === key && twoFAEnabled
                      ? 'border-[#fa3f5e] bg-[#fa3f5e]/5'
                      : isEditing
                      ? 'border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800'
                      : 'border-gray-100 dark:border-gray-800 bg-gray-50/50 dark:bg-gray-800/30'
                  } disabled:cursor-not-allowed ${(!isEditing && twoFAMethod !== key) ? 'opacity-50' : ''}`}>
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                    twoFAMethod === key && twoFAEnabled ? 'bg-[#fa3f5e]/10 text-[#fa3f5e]' : 'bg-gray-100 dark:bg-gray-800 text-gray-500'
                  }`}>
                    <Icon size={15} />
                  </div>
                  <div className="flex-1 text-left">
                    <p className={`text-sm font-medium ${isEditing || twoFAMethod === key ? 'text-gray-900 dark:text-white' : 'text-gray-400 dark:text-gray-500'}`}>{label}</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400">{sublabel}</p>
                  </div>
                  <div className={`w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0 ${
                    twoFAMethod === key && twoFAEnabled ? 'border-[#fa3f5e]' : 'border-gray-300 dark:border-gray-600'
                  }`}>
                    {twoFAMethod === key && twoFAEnabled && <span className="w-2 h-2 rounded-full bg-[#fa3f5e]" />}
                  </div>
                </button>
              ))}
            </div>

            {twoFAEnabled && (
              <div className="mx-4 mb-3 flex items-center gap-2 p-2.5 rounded-xl bg-green-50 dark:bg-green-900/10 border border-green-100 dark:border-green-900/30">
                <ShieldCheck size={13} className="text-green-600 shrink-0" />
                <p className="text-xs text-green-700 dark:text-green-400">2FA active — a code will be required at each login.</p>
              </div>
            )}
            {twoFAMethod === 'sms' && !userPhone && (
              <div className="mx-4 mb-3 flex items-center gap-2 p-2.5 rounded-xl bg-orange-50 dark:bg-orange-900/10 border border-orange-200 dark:border-orange-900/30">
                <AlertCircle size={13} className="text-orange-500 shrink-0" />
                <p className="text-xs text-orange-700 dark:text-orange-400">No phone number on your account. Add one in Profile settings to use SMS OTP.</p>
              </div>
            )}
          </div>
        </div>

        {/* ── Login Activity ─────────────────────────────── */}
        <div>
          <SectionTitle title="Login Activity" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* Active Devices */}
            <button onClick={loadSessions}
              className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 border-b border-gray-100 dark:border-gray-800 transition-colors">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-blue-50 dark:bg-gray-800 flex items-center justify-center text-blue-500">
                  <Monitor size={18} />
                </div>
                <div className="text-left">
                  <p className="font-medium text-gray-900 dark:text-white text-sm">Active Devices</p>
                  <p className="text-xs text-gray-500">Devices currently logged in</p>
                </div>
              </div>
              <ChevronRight size={16} className={`text-gray-400 transition-transform ${showActivity ? 'rotate-90' : ''}`} />
            </button>

            {showActivity && (
              <div className="border-b border-gray-100 dark:border-gray-800">
                {sessionsLoading ? (
                  <div className="flex items-center justify-center py-8 gap-2 text-gray-400">
                    <Loader2 size={16} className="animate-spin" /> <span className="text-sm">Loading…</span>
                  </div>
                ) : sessions.length === 0 ? (
                  <div className="text-center py-8">
                    <Monitor size={28} className="text-gray-300 dark:text-gray-600 mx-auto mb-2" />
                    <p className="text-sm text-gray-500">No active sessions found.</p>
                  </div>
                ) : (
                  <div className="divide-y divide-gray-100 dark:divide-gray-800">
                    {sessions.map((s, i) => {
                      const sessionId = s._id || s.id;
                      const isCurrent = s.isCurrent || s.is_current || false;
                      const deviceName = s.deviceName || s.device || s.user_agent || 'Unknown Device';
                      const deviceType = s.deviceType || s.device_type || 'desktop';
                      const location = s.location || '';
                      const ip = s.ip || '';
                      const lastActive = s.lastActive || s.last_active || s.created_at;
                      const DeviceIcon = deviceType === 'mobile' || deviceType === 'tablet' ? Smartphone : Monitor;
                      return (
                        <div key={sessionId || i} className="flex items-start gap-3 px-4 py-3">
                          <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${isCurrent ? 'bg-green-50 dark:bg-green-900/20 text-green-600' : 'bg-gray-100 dark:bg-gray-800 text-gray-500'}`}>
                            <DeviceIcon size={16} />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <p className="text-sm font-medium text-gray-900 dark:text-white">{deviceName}</p>
                              {isCurrent && <span className="text-[10px] font-bold bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400 px-1.5 py-0.5 rounded-full">Current</span>}
                            </div>
                            <p className="text-xs text-gray-500">{[location, ip].filter(Boolean).join(' · ') || '—'}</p>
                            <p className="text-xs text-gray-400">{formatDate(lastActive)}</p>
                          </div>
                          {!isCurrent && sessionId && (
                            <button onClick={() => handleRemoveSession(sessionId)}
                              className="flex-shrink-0 p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors">
                              <X size={14} />
                            </button>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}

            {/* Login History */}
            <button onClick={loadHistory}
              className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-purple-50 dark:bg-gray-800 flex items-center justify-center text-purple-500">
                  <Clock size={18} />
                </div>
                <div className="text-left">
                  <p className="font-medium text-gray-900 dark:text-white text-sm">Login History</p>
                  <p className="text-xs text-gray-500">Recent login activity</p>
                </div>
              </div>
              <ChevronRight size={16} className={`text-gray-400 transition-transform ${showHistory ? 'rotate-90' : ''}`} />
            </button>

            {showHistory && (
              <div className="border-t border-gray-100 dark:border-gray-800">
                {loginHistory.length === 0 ? (
                  <div className="text-center py-8">
                    <Clock size={28} className="text-gray-300 dark:text-gray-600 mx-auto mb-2" />
                    <p className="text-sm text-gray-500">No login history available.</p>
                  </div>
                ) : (
                  <div className="divide-y divide-gray-100 dark:divide-gray-800">
                    {loginHistory.slice(0, 20).map((h, i) => {
                      const deviceName = h.deviceName || h.device || 'Unknown Device';
                      const ip = h.ip || '—';
                      const location = h.location || '';
                      const timestamp = h.loginAt || h.created_at || h.timestamp;
                      const ok = h.status === 'success' || h.status === 'ok';
                      return (
                        <div key={h._id || i} className="flex items-start gap-3 px-4 py-3">
                          <div className={`w-2 h-2 rounded-full mt-2 flex-shrink-0 ${ok ? 'bg-green-500' : 'bg-red-400'}`} />
                          <div className="flex-1 min-w-0">
                            <p className="text-sm text-gray-900 dark:text-white font-medium">{deviceName}</p>
                            <p className="text-xs text-gray-500">{[ip, location].filter(v => v && v !== '—').join(' · ') || ip}</p>
                            <p className="text-xs text-gray-400">{formatDate(timestamp)}</p>
                          </div>
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full flex-shrink-0 ${ok ? 'bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400' : 'bg-red-100 text-red-600 dark:bg-red-900/20 dark:text-red-400'}`}>
                            {ok ? 'OK' : 'Failed'}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* ── Security Controls ──────────────────────────── */}
        <div>
          <SectionTitle title="Security Controls" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            <button onClick={handleLogoutCurrent}
              className="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 border-b border-gray-100 dark:border-gray-800 transition-colors">
              <div className="w-9 h-9 rounded-full bg-orange-50 dark:bg-gray-800 flex items-center justify-center text-orange-500 flex-shrink-0">
                <LogOut size={18} />
              </div>
              <div className="flex-1 text-left">
                <p className="font-medium text-gray-900 dark:text-white text-sm">Logout from This Device</p>
                <p className="text-xs text-gray-500">End the current session</p>
              </div>
              <ChevronRight size={16} className="text-gray-400" />
            </button>

            <button onClick={() => setConfirmLogoutAll(true)}
              className="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors">
              <div className="w-9 h-9 rounded-full bg-red-50 dark:bg-gray-800 flex items-center justify-center text-red-500 flex-shrink-0">
                <Trash2 size={18} />
              </div>
              <div className="flex-1 text-left">
                <p className="font-medium text-red-600 dark:text-red-400 text-sm">Logout from All Devices</p>
                <p className="text-xs text-gray-500">Remove all active sessions everywhere</p>
              </div>
              <ChevronRight size={16} className="text-red-300" />
            </button>
          </div>
        </div>

      </div>

      {/* Modals */}
      {twoFAModal && (
        <TwoFAModal mode={twoFAModal} method={twoFAMethod} email={userEmail} phone={userPhone} userId={userId}
          onClose={() => setTwoFAModal(null)}
          onDone={async (enabled) => {
            setTwoFAEnabled(enabled);
            setTwoFAModal(null);
            await dispatch(fetchMe());
          }} />
      )}

      {showReset && <ResetPasswordModal email={userEmail} onClose={() => setShowReset(false)} />}

      {confirmLogoutAll && (
        <ConfirmModal
          title="Logout from All Devices?"
          message="You will be signed out from every device where your account is active, including this one."
          confirmLabel="Logout All"
          confirmClass="bg-red-500 hover:bg-red-600"
          loading={logoutAllLoading}
          onConfirm={handleLogoutAllDevices}
          onClose={() => setConfirmLogoutAll(false)} />
      )}
    </div>
  );
};

export default SecuritySettings;
