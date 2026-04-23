import React, { useState, useRef, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import api from '../lib/api';
import { logoutUser } from '../store/authSlice';
import { fetchMe } from '../store/authSlice';
import { toggleTheme } from '../store/themeSlice';
import {
  ArrowLeft, Globe2, Bell, Shield, Lock, SlidersHorizontal,
  Info, HelpCircle, ChevronRight, LogOut, Loader2, Moon, Sun,
  ShieldCheck, KeyRound, Mail, Eye, EyeOff, CheckCircle2,
  AlertCircle, X, RefreshCw, Smartphone, Users, UserCheck,
  UserX, Clock, Check,
} from 'lucide-react';
import {
  getPrivacyStatus,
  setAccountPrivacy,
  getFollowRequests,
  acceptFollowRequest,
  declineFollowRequest,
} from '../services/followService';

const BASE = "https://api.bebsmart.in";

// ── Shared sub-components ─────────────────────────────────────────────────────
const PasswordInput = ({ value, onChange, placeholder }) => {
  const [show, setShow] = useState(false);
  return (
    <div className="relative">
      <input
        type={show ? "text" : "password"}
        value={value}
        onChange={onChange}
        placeholder={placeholder}
        className="w-full px-4 py-2.5 pr-10 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-pink-500/20 focus:border-pink-500 placeholder-gray-400 dark:placeholder-gray-600 transition-all"
      />
      <button
        type="button"
        onClick={() => setShow(v => !v)}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
      >
        {show ? <EyeOff size={15} /> : <Eye size={15} />}
      </button>
    </div>
  );
};

const OtpInput = ({ value, onChange, length = 6 }) => {
  const inputs = useRef([]);
  const digits = value.split("").concat(Array(length).fill("")).slice(0, length);

  const handleKey = (i, e) => {
    if (e.key === "Backspace" && !digits[i] && i > 0) inputs.current[i - 1]?.focus();
  };
  const handleChange = (i, v) => {
    const d = v.replace(/\D/g, "").slice(-1);
    const next = [...digits]; next[i] = d;
    onChange(next.join(""));
    if (d && i < length - 1) inputs.current[i + 1]?.focus();
  };
  const handlePaste = (e) => {
    const p = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, length);
    onChange(p.padEnd(length, "").slice(0, length));
    inputs.current[Math.min(p.length, length - 1)]?.focus();
  };

  return (
    <div className="flex gap-2 justify-center">
      {digits.map((d, i) => (
        <input
          key={i}
          ref={el => inputs.current[i] = el}
          type="text"
          inputMode="numeric"
          maxLength={1}
          value={d}
          onChange={e => handleChange(i, e.target.value)}
          onKeyDown={e => handleKey(i, e)}
          onPaste={handlePaste}
          className="w-10 h-11 text-center text-base font-bold rounded-xl border-2 border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-gray-900 dark:text-white focus:border-[#fa3f5e] focus:ring-2 focus:ring-[#fa3f5e]/20 outline-none transition-all"
        />
      ))}
    </div>
  );
};

const AlertBanner = ({ type, msg }) => {
  if (!msg) return null;
  return (
    <div className={`flex items-center gap-2 px-3 py-2.5 rounded-xl text-sm font-medium mb-4 border ${
      type === "success"
        ? "bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-700 dark:text-green-400"
        : "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-600 dark:text-red-400"
    }`}>
      {type === "success" ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />}
      {msg}
    </div>
  );
};

// ── 2FA Modal ─────────────────────────────────────────────────────────────────
const TwoFAModal = ({ mode, email, userId, onClose, onDone }) => {
  const [step, setStep] = useState(1);
  const [otp, setOtp] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown > 0) {
      const t = setTimeout(() => setCooldown(c => c - 1), 1000);
      return () => clearTimeout(t);
    }
  }, [cooldown]);

  const sendOtp = async () => {
    setError(""); setLoading(true);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${BASE}/api/email/send-otp`, {
        method: "POST",
        headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify({ email, purpose: "two_factor" }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || "Failed to send OTP");
      setStep(2); setCooldown(60);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  const verifyOtp = async () => {
    if (otp.length < 6) { setError("Enter all 6 digits."); return; }
    setError(""); setLoading(true);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${BASE}/api/email/verify-otp`, {
        method: "POST",
        headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify({ email, otp, purpose: "two_factor" }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || "Invalid OTP");
      await api.put(`/users/${userId}`, {
        twoFA: { enabled: mode === "enable" }
      }, {
        headers: token ? { Authorization: `Bearer ${token}` } : {}
      });
      setSuccess(mode === "enable" ? "2FA enabled!" : "2FA disabled!");
      setTimeout(() => onDone(mode === "enable"), 1400);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-xs bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-5 relative">
        <button onClick={onClose} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 p-1">
          <X size={16} />
        </button>

        <div className="flex items-center gap-2.5 mb-4">
          <div className={`p-2 rounded-xl ${mode === "enable" ? "bg-green-50 dark:bg-green-900/20 text-green-600" : "bg-red-50 dark:bg-red-900/20 text-red-500"}`}>
            <ShieldCheck size={18} />
          </div>
          <div>
            <p className="font-bold text-sm text-gray-900 dark:text-white">{mode === "enable" ? "Enable 2FA" : "Disable 2FA"}</p>
            <p className="text-xs text-gray-500">{email}</p>
          </div>
        </div>

        <AlertBanner type="success" msg={success} />
        <AlertBanner type="error" msg={error} />

        {step === 1 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">
              {mode === "enable"
                ? "A verification code will be sent to your email to confirm enabling 2FA."
                : "We need to verify your identity before disabling 2FA."}
            </p>
            <button
              onClick={sendOtp}
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading ? <><Loader2 size={14} className="animate-spin" /> Sending…</> : <><Mail size={14} /> Send Code</>}
            </button>
          </>
        )}

        {step === 2 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-4 text-center">
              Enter the 6-digit code sent to your email
            </p>
            <div className="mb-4"><OtpInput value={otp} onChange={setOtp} /></div>
            <button
              onClick={verifyOtp}
              disabled={loading || otp.length < 6}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60 mb-2"
            >
              {loading ? <><Loader2 size={14} className="animate-spin" /> Verifying…</> : "Verify & Confirm"}
            </button>
            <button
              onClick={() => { setOtp(""); sendOtp(); }}
              disabled={cooldown > 0 || loading}
              className="w-full py-2 rounded-xl border border-gray-200 dark:border-gray-800 text-xs text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              <RefreshCw size={12} />
              {cooldown > 0 ? `Resend in ${cooldown}s` : "Resend Code"}
            </button>
          </>
        )}
      </div>
    </div>
  );
};

// ── Reset Password Modal ──────────────────────────────────────────────────────
const ResetPasswordModal = ({ email, onClose }) => {
  const [step, setStep] = useState(1);
  const [token, setToken] = useState("");
  const [newPass, setNewPass] = useState("");
  const [confirmPass, setConfirmPass] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const sendLink = async () => {
    setError(""); setLoading(true);
    try {
      const res = await fetch(`${BASE}/api/email/forgot-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || "Failed to send reset link");
      setStep(2);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  const doReset = async () => {
    if (!token.trim()) { setError("Please enter the reset token."); return; }
    if (newPass.length < 6) { setError("Password must be at least 6 characters."); return; }
    if (newPass !== confirmPass) { setError("Passwords do not match."); return; }
    setError(""); setLoading(true);
    try {
      const res = await fetch(`${BASE}/api/email/reset-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, newPassword: newPass }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.message || "Failed to reset password");
      setStep(3);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-xs bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-5 relative">
        <button onClick={onClose} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 p-1">
          <X size={16} />
        </button>

        <div className="flex items-center gap-2.5 mb-4">
          <div className="p-2 rounded-xl bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">
            <KeyRound size={18} />
          </div>
          <div>
            <p className="font-bold text-sm text-gray-900 dark:text-white">Reset Password</p>
            <p className="text-xs text-gray-500">via email link</p>
          </div>
        </div>

        <AlertBanner type="error" msg={error} />

        {step === 1 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">A reset link will be sent to:</p>
            <div className="px-3 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 text-xs font-semibold text-gray-800 dark:text-white mb-4 break-all">
              {email}
            </div>
            <button
              onClick={sendLink}
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading ? <><Loader2 size={14} className="animate-spin" /> Sending…</> : <><Mail size={14} /> Send Reset Link</>}
            </button>
          </>
        )}

        {step === 2 && (
          <>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">
              Check your email for the reset token, paste it below and set your new password.
            </p>
            <div className="space-y-2.5 mb-4">
              <input
                type="text"
                value={token}
                onChange={e => setToken(e.target.value)}
                placeholder="Paste reset token"
                className="w-full px-3 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] placeholder-gray-400 dark:placeholder-gray-600 transition-all"
              />
              <PasswordInput value={newPass} onChange={e => setNewPass(e.target.value)} placeholder="New Password" />
              <PasswordInput value={confirmPass} onChange={e => setConfirmPass(e.target.value)} placeholder="Confirm New Password" />
            </div>
            <button
              onClick={doReset}
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading ? <><Loader2 size={14} className="animate-spin" /> Resetting…</> : "Reset Password"}
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
            <button
              onClick={onClose}
              className="px-5 py-2 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity"
            >
              Done
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

// ── Security Screen ───────────────────────────────────────────────────────────
const SecurityScreen = ({ onBack, email, userId }) => {
  const dispatch = useDispatch();
  const [twoFAEnabled, setTwoFAEnabled] = useState(false);
  const [twoFAModal, setTwoFAModal] = useState(null);
  const [showReset, setShowReset] = useState(false);
  const [showChangePwd, setShowChangePwd] = useState(false);
  const [passwords, setPasswords] = useState({ current: "", newPass: "", confirm: "" });
  const [pwdLoading, setPwdLoading] = useState(false);
  const [pwdSuccess, setPwdSuccess] = useState("");
  const [pwdError, setPwdError] = useState("");

  useEffect(() => {
    const loadMe = async () => {
      try {
        const res = await api.get('/auth/me');
        setTwoFAEnabled(!!res.data?.twoFA?.enabled);
      } catch (error) {
        console.error('Failed to load 2FA status:', error);
      }
    };
    loadMe();
  }, []);

  const handleChangePassword = async () => {
    setPwdError(""); setPwdSuccess("");
    if (!passwords.current.trim()) { setPwdError("Current password is required."); return; }
    if (passwords.newPass.length < 6) { setPwdError("New password must be at least 6 characters."); return; }
    if (passwords.newPass !== passwords.confirm) { setPwdError("Passwords do not match."); return; }
    setPwdLoading(true);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${BASE}/api/auth/change-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify({ currentPassword: passwords.current, newPassword: passwords.newPass, user_id: userId }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        setPwdSuccess("Password updated!"); setPasswords({ current: "", newPass: "", confirm: "" });
        setTimeout(() => setPwdSuccess(""), 4000);
      } else {
        setPwdError(data?.message || data?.error || "Failed to update password.");
      }
    } catch { setPwdError("Network error."); }
    finally { setPwdLoading(false); }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-20">
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex items-center gap-3 z-40">
        <button onClick={onBack} className="text-gray-800 dark:text-white">
          <ArrowLeft size={22} />
        </button>
        <h1 className="text-base font-semibold dark:text-white">Security</h1>
      </div>

      <div className="max-w-2xl mx-auto pt-4 px-4 space-y-4">
        {/* 2FA Card */}
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-4 shadow-sm">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
              <ShieldCheck size={18} />
            </div>
            <div className="flex-1">
              <p className="font-semibold text-gray-900 dark:text-white text-sm">Two-Factor Authentication</p>
              <p className="text-xs text-gray-500">Extra security via email OTP on login</p>
            </div>
            <div className="flex items-center gap-2">
              <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${twoFAEnabled ? "bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400" : "bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400"}`}>
                {twoFAEnabled ? "ON" : "OFF"}
              </span>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={twoFAEnabled}
                  onChange={() => setTwoFAModal(twoFAEnabled ? "disable" : "enable")}
                  className="sr-only peer"
                />
                <div className="w-10 h-5 rounded-full bg-gray-300 dark:bg-gray-700 peer-checked:bg-[#fa3f5e] transition-colors" />
                <div className="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow transform transition-transform peer-checked:translate-x-5" />
              </label>
            </div>
          </div>
          {twoFAEnabled && (
            <div className="flex items-center gap-2 p-2.5 rounded-xl bg-green-50 dark:bg-green-900/10 border border-green-100 dark:border-green-900/30">
              <Smartphone size={13} className="text-green-600 shrink-0" />
              <p className="text-xs text-green-700 dark:text-green-400">2FA is active — email OTP required at each login.</p>
            </div>
          )}
        </div>

        {/* Change Password Card */}
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm overflow-hidden">
          <button
            onClick={() => setShowChangePwd(v => !v)}
            className="w-full flex items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
                <Lock size={18} />
              </div>
              <div className="text-left">
                <p className="font-medium text-gray-900 dark:text-white text-sm">Change Password</p>
                <p className="text-xs text-gray-500">Update your current password</p>
              </div>
            </div>
            <ChevronRight size={16} className={`text-gray-400 transition-transform ${showChangePwd ? "rotate-90" : ""}`} />
          </button>

          {showChangePwd && (
            <div className="px-4 pb-4 space-y-3 border-t border-gray-100 dark:border-gray-800 pt-4">
              <AlertBanner type="success" msg={pwdSuccess} />
              <AlertBanner type="error" msg={pwdError} />
              <PasswordInput value={passwords.current} onChange={e => setPasswords({ ...passwords, current: e.target.value })} placeholder="Current Password" />
              <PasswordInput value={passwords.newPass} onChange={e => setPasswords({ ...passwords, newPass: e.target.value })} placeholder="New Password" />
              <PasswordInput value={passwords.confirm} onChange={e => setPasswords({ ...passwords, confirm: e.target.value })} placeholder="Confirm New Password" />
              {passwords.newPass && (
                <div className="flex items-center gap-1.5">
                  {[1,2,3,4].map(i => (
                    <div key={i} className={`flex-1 h-1 rounded-full transition-colors ${
                      passwords.newPass.length >= i * 3
                        ? i <= 1 ? "bg-red-400" : i <= 2 ? "bg-orange-400" : i <= 3 ? "bg-yellow-400" : "bg-green-500"
                        : "bg-gray-200 dark:bg-gray-700"
                    }`} />
                  ))}
                  <span className="text-[10px] text-gray-400 whitespace-nowrap">
                    {passwords.newPass.length < 4 ? "Weak" : passwords.newPass.length < 7 ? "Fair" : passwords.newPass.length < 10 ? "Good" : "Strong"}
                  </span>
                </div>
              )}
              <button
                onClick={handleChangePassword}
                disabled={pwdLoading}
                className="w-full py-2.5 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
              >
                {pwdLoading ? <><Loader2 size={14} className="animate-spin" /> Updating…</> : "Update Password"}
              </button>
            </div>
          )}
        </div>

        {/* Reset Password via Email */}
        <button
          onClick={() => setShowReset(true)}
          className="w-full flex items-center justify-between p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
        >
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

      {twoFAModal && (
        <TwoFAModal
          mode={twoFAModal}
          email={email}
          userId={userId}
          onClose={() => setTwoFAModal(null)}
          onDone={async (enabled) => {
            setTwoFAEnabled(enabled);
            setTwoFAModal(null);
            await dispatch(fetchMe());
          }}
        />
      )}
      {showReset && <ResetPasswordModal email={email} onClose={() => setShowReset(false)} />}
    </div>
  );
};

// ── Account Privacy Screen ────────────────────────────────────────────────────
const PrivacyScreen = ({ onBack }) => {
  const [isPrivate, setIsPrivate] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [toggling, setToggling] = useState(false);
  const [requests, setRequests] = useState([]);
  const [loadingRequests, setLoadingRequests] = useState(false);
  const [showRequests, setShowRequests] = useState(false);
  const [actionLoading, setActionLoading] = useState({}); // { [userId]: 'accept'|'decline' }
  const [toast, setToast] = useState(null);

  useEffect(() => {
    const load = async () => {
      try {
        const status = await getPrivacyStatus();
        setIsPrivate(status.isPrivate);
        setPendingCount(status.pendingRequestsCount || 0);
      } catch (e) {
        console.error('Failed to load privacy status:', e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const handleTogglePrivacy = async () => {
    if (toggling) return;
    setToggling(true);
    try {
      const result = await setAccountPrivacy(!isPrivate);
      setIsPrivate(result.isPrivate);
      if (!result.isPrivate) {
        // Going public auto-accepts all pending
        setPendingCount(0);
        setRequests([]);
      }
      showToast(result.message || `Account is now ${result.isPrivate ? 'private' : 'public'}`);
    } catch (e) {
      console.error('Failed to toggle privacy:', e);
      showToast('Failed to update privacy settings.', 'error');
    } finally {
      setToggling(false);
    }
  };

  const handleLoadRequests = async () => {
    if (showRequests) {
      setShowRequests(false);
      return;
    }
    setLoadingRequests(true);
    setShowRequests(true);
    try {
      const data = await getFollowRequests();
      setRequests(data.requests || []);
      setPendingCount(data.count || 0);
    } catch (e) {
      console.error('Failed to load follow requests:', e);
      showToast('Failed to load follow requests.', 'error');
    } finally {
      setLoadingRequests(false);
    }
  };

  const handleAccept = async (requesterId) => {
    setActionLoading(prev => ({ ...prev, [requesterId]: 'accept' }));
    try {
      await acceptFollowRequest(requesterId);
      setRequests(prev => prev.filter(r => (r._id || r.id) !== requesterId));
      setPendingCount(prev => Math.max(0, prev - 1));
      showToast('Follow request accepted.');
    } catch (e) {
      showToast('Failed to accept request.', 'error');
    } finally {
      setActionLoading(prev => { const n = { ...prev }; delete n[requesterId]; return n; });
    }
  };

  const handleDecline = async (requesterId) => {
    setActionLoading(prev => ({ ...prev, [requesterId]: 'decline' }));
    try {
      await declineFollowRequest(requesterId);
      setRequests(prev => prev.filter(r => (r._id || r.id) !== requesterId));
      setPendingCount(prev => Math.max(0, prev - 1));
      showToast('Follow request declined.');
    } catch (e) {
      showToast('Failed to decline request.', 'error');
    } finally {
      setActionLoading(prev => { const n = { ...prev }; delete n[requesterId]; return n; });
    }
  };

  const getInitials = (name) => {
    if (!name) return 'U';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().substring(0, 2);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-20">
      {/* Toast */}
      {toast && (
        <div className={`fixed top-20 right-4 z-[80] rounded-xl border px-4 py-3 text-sm font-semibold shadow-lg ${
          toast.type === 'success'
            ? 'border-green-200 bg-green-50 text-green-700 dark:border-green-800 dark:bg-green-900/20 dark:text-green-400'
            : 'border-red-200 bg-red-50 text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400'
        }`}>
          {toast.msg}
        </div>
      )}

      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex items-center gap-3 z-40">
        <button onClick={onBack} className="text-gray-800 dark:text-white">
          <ArrowLeft size={22} />
        </button>
        <h1 className="text-base font-semibold dark:text-white">Account Privacy</h1>
      </div>

      <div className="max-w-2xl mx-auto pt-4 px-4 space-y-4">

        {/* Private Account Toggle Card */}
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
              <Lock size={20} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-gray-900 dark:text-white text-sm">Private Account</p>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                {loading ? 'Loading…' : isPrivate ? 'Only approved followers can see your posts' : 'Anyone can follow and see your posts'}
              </p>
            </div>
            <label className="relative inline-flex items-center cursor-pointer flex-shrink-0">
              <input
                type="checkbox"
                checked={isPrivate}
                onChange={handleTogglePrivacy}
                disabled={loading || toggling}
                className="sr-only peer"
              />
              <div className={`w-11 h-6 rounded-full transition-colors duration-200 ${isPrivate ? 'bg-[#fa3f5e]' : 'bg-gray-300 dark:bg-gray-700'} peer-disabled:opacity-50`} />
              <div className={`absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform duration-200 ${isPrivate ? 'translate-x-5' : 'translate-x-0'}`}>
                {toggling && <Loader2 size={12} className="animate-spin text-gray-400 m-0.5" />}
              </div>
            </label>
          </div>
        </div>

        {/* Explanation Card */}
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-4 shadow-sm space-y-3">
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center flex-shrink-0 mt-0.5">
              <Users size={16} className="text-gray-500" />
            </div>
            <div>
              <p className="text-sm font-medium text-gray-800 dark:text-white">When your account is <span className="text-green-600 dark:text-green-400">public</span></p>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 leading-relaxed">
                Your profile and posts can be seen by anyone. Anyone can follow you without approval.
              </p>
            </div>
          </div>
          <div className="h-px bg-gray-100 dark:bg-gray-800" />
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center flex-shrink-0 mt-0.5">
              <Lock size={16} className="text-gray-500" />
            </div>
            <div>
              <p className="text-sm font-medium text-gray-800 dark:text-white">When your account is <span className="text-[#fa3f5e]">private</span></p>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 leading-relaxed">
                Only followers you approve can see your photos and videos. Existing followers won't be affected.
              </p>
            </div>
          </div>
        </div>

        {/* Follow Requests — only visible when account is private */}
        {isPrivate && (
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm overflow-hidden">
            <button
              onClick={handleLoadRequests}
              className="w-full flex items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
                  <Clock size={20} />
                </div>
                <div className="text-left">
                  <p className="font-medium text-gray-900 dark:text-white text-sm">Follow Requests</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    {pendingCount > 0 ? `${pendingCount} pending request${pendingCount > 1 ? 's' : ''}` : 'No pending requests'}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {pendingCount > 0 && (
                  <span className="text-xs font-bold bg-[#fa3f5e] text-white w-5 h-5 rounded-full flex items-center justify-center">
                    {pendingCount > 9 ? '9+' : pendingCount}
                  </span>
                )}
                <ChevronRight size={16} className={`text-gray-400 transition-transform ${showRequests ? 'rotate-90' : ''}`} />
              </div>
            </button>

            {showRequests && (
              <div className="border-t border-gray-100 dark:border-gray-800">
                {loadingRequests ? (
                  <div className="flex items-center justify-center py-8 gap-2 text-gray-400">
                    <Loader2 size={18} className="animate-spin" />
                    <span className="text-sm">Loading requests…</span>
                  </div>
                ) : requests.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-10 text-center px-4">
                    <div className="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-3">
                      <UserCheck size={22} className="text-gray-400" />
                    </div>
                    <p className="text-sm font-medium text-gray-700 dark:text-gray-300">No pending requests</p>
                    <p className="text-xs text-gray-400 mt-1">Follow requests will appear here</p>
                  </div>
                ) : (
                  <div className="divide-y divide-gray-100 dark:divide-gray-800">
                    {requests.map((req) => {
                      const reqId = req._id || req.id;
                      const isActing = actionLoading[reqId];
                      return (
                        <div key={reqId} className="flex items-center gap-3 px-4 py-3">
                          {/* Avatar */}
                          <div className="w-11 h-11 rounded-full overflow-hidden bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 flex-shrink-0">
                            {req.profilePicture ? (
                              <img src={req.profilePicture} alt={req.username} className="w-full h-full object-cover" />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center text-sm font-bold text-gray-500 dark:text-gray-400">
                                {getInitials(req.username)}
                              </div>
                            )}
                          </div>

                          {/* Info */}
                          <div className="flex-1 min-w-0">
                            <p className="font-semibold text-sm text-gray-900 dark:text-white truncate">{req.username}</p>
                            {req.bio && <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{req.bio}</p>}
                            <p className="text-[11px] text-gray-400 mt-0.5">
                              {fmt(req.followers_count || 0)} followers
                            </p>
                          </div>

                          {/* Actions */}
                          <div className="flex items-center gap-2 flex-shrink-0">
                            <button
                              onClick={() => handleAccept(reqId)}
                              disabled={!!isActing}
                              className="px-3.5 py-1.5 bg-[#fa3f5e] text-white text-xs font-bold rounded-xl hover:opacity-90 transition-opacity disabled:opacity-50 flex items-center gap-1"
                            >
                              {isActing === 'accept' ? <Loader2 size={12} className="animate-spin" /> : <Check size={12} />}
                              Confirm
                            </button>
                            <button
                              onClick={() => handleDecline(reqId)}
                              disabled={!!isActing}
                              className="px-3.5 py-1.5 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 text-xs font-bold rounded-xl hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors disabled:opacity-50 flex items-center gap-1"
                            >
                              {isActing === 'decline' ? <Loader2 size={12} className="animate-spin" /> : <X size={12} />}
                              Delete
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

// ── Main Settings ─────────────────────────────────────────────────────────────
const settingsSections = [
  {
    title: 'Preferences',
    items: [
      { icon: Globe2, label: 'Language / Region', subLabel: 'Default: English' },
      { icon: Bell, label: 'Notifications', subLabel: 'Manage notifications' },
    ],
  },
  {
    title: 'Account',
    items: [
      { icon: Shield, label: 'Privacy', subLabel: 'Account privacy & follow requests', key: 'privacy' },
      { icon: Lock, label: 'Security', subLabel: 'Password & 2FA', key: 'security' },
      { icon: SlidersHorizontal, label: 'Content Settings', subLabel: 'Moderation & restrictions' },
    ],
  },
  {
    title: 'About',
    items: [
      { icon: Info, label: 'About b Smart', subLabel: 'Version 1.0.0' },
      { icon: HelpCircle, label: 'Help & Support', subLabel: 'Contact support' },
    ],
  },
];

const Settings = () => {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { mode } = useSelector((state) => state.theme);
  const { userObject } = useSelector((state) => state.auth);
  const [loggingOut, setLoggingOut] = useState(false);
  const [screen, setScreen] = useState(null); // null | "security" | "privacy"

  const userEmail = userObject?.email || "";
  const userId = userObject?._id || userObject?.id;

  const handleLogout = async () => {
    try {
      setLoggingOut(true);
      localStorage.removeItem('token');
      dispatch(logoutUser());
      navigate('/login');
    } catch (error) {
      console.error('Error logging out:', error);
    } finally {
      setLoggingOut(false);
    }
  };

  if (screen === "security") {
    return <SecurityScreen onBack={() => setScreen(null)} email={userEmail} userId={userId} />;
  }

  if (screen === "privacy") {
    return <PrivacyScreen onBack={() => setScreen(null)} />;
  }

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-20">
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex justify-between items-center z-40">
        <Link to="/profile" className="text-gray-800 dark:text-white">
          <ArrowLeft size={24} />
        </Link>
        <h1 className="text-lg font-semibold dark:text-white">Settings</h1>
        <div className="w-6" />
      </div>

      <div className="max-w-2xl mx-auto pt-4 px-4">
        {settingsSections.map((section) => (
          <div key={section.title} className="mb-6">
            <h2 className="text-xs font-semibold text-[#fa3f5e] mb-2 uppercase tracking-wide">{section.title}</h2>

            <div className="space-y-3">
              {section.title === 'Preferences' && (
                <button
                  onClick={() => dispatch(toggleTheme())}
                  className="w-full flex items-center justify-between p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-left"
                >
                  <div className="flex items-center gap-4">
                    <div className="w-10 h-10 rounded-full bg-purple-50 dark:bg-gray-800 flex items-center justify-center text-purple-500">
                      {mode === 'dark' ? <Moon size={20} strokeWidth={2.5} /> : <Sun size={20} strokeWidth={2.5} />}
                    </div>
                    <div className="flex flex-col">
                      <span className="font-medium text-gray-900 dark:text-white">Appearance</span>
                      <span className="text-xs text-gray-500 dark:text-gray-400">{mode === 'dark' ? 'Dark Mode' : 'Light Mode'}</span>
                    </div>
                  </div>
                  <div className={`w-11 h-6 rounded-full p-1 transition-colors duration-200 ease-in-out flex items-center ${mode === 'dark' ? 'bg-[#fa3f5e]' : 'bg-gray-300'}`}>
                    <div className={`bg-white w-4 h-4 rounded-full shadow-md transform transition-transform duration-200 ease-in-out ${mode === 'dark' ? 'translate-x-5' : 'translate-x-0'}`} />
                  </div>
                </button>
              )}
              {section.items.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.label}
                    onClick={() => {
                      if (item.key === 'security') setScreen('security');
                      else if (item.key === 'privacy') setScreen('privacy');
                    }}
                    className="w-full flex items-center justify-between p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-left"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e]">
                        <Icon size={20} strokeWidth={2.5} />
                      </div>
                      <div className="flex flex-col">
                        <span className="font-medium text-gray-900 dark:text-white">{item.label}</span>
                        {item.subLabel && <span className="text-xs text-gray-500 dark:text-gray-400">{item.subLabel}</span>}
                      </div>
                    </div>
                    <ChevronRight size={18} className="text-gray-400" />
                  </button>
                );
              })}
            </div>
          </div>
        ))}

        <div className="mb-6">
          <h2 className="text-xs font-semibold text-[#fa3f5e] mb-2 uppercase tracking-wide">Actions</h2>
          <button
            onClick={handleLogout}
            disabled={loggingOut}
            className="w-full flex items-center justify-between p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors text-left group"
          >
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 rounded-full bg-red-50 dark:bg-red-900/20 flex items-center justify-center text-red-500 group-hover:bg-red-100 dark:group-hover:bg-red-900/30 transition-colors">
                {loggingOut ? <Loader2 size={20} className="animate-spin" /> : <LogOut size={20} strokeWidth={2.5} />}
              </div>
              <div className="flex flex-col">
                <span className="font-medium text-red-600">{loggingOut ? 'Logging out...' : 'Log Out'}</span>
                <span className="text-xs text-gray-500 dark:text-gray-400">Sign out of your account</span>
              </div>
            </div>
          </button>
        </div>
      </div>
    </div>
  );
};

export default Settings;