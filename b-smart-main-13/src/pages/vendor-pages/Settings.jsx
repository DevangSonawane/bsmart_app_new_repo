import { useState, useRef, useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import api from "../../lib/api";
import { fetchMe } from "../../store/authSlice";
import {
  Lock, ShieldCheck, UserPlus, UserCog, Mail, MessageSquare,
  Eye, EyeOff, CheckCircle2, AlertCircle, Loader2, KeyRound,
  Shield, RefreshCw, X, Smartphone
} from "lucide-react";

const BASE = "https://api.bebsmart.in"; 

const Toggle = ({ checked, onChange }) => (
  <label className="relative inline-flex items-center cursor-pointer">
    <input type="checkbox" checked={checked} onChange={onChange} className="sr-only peer" />
    <div className="w-11 h-6 rounded-full bg-gray-300 dark:bg-gray-700 peer-checked:bg-emerald-500 transition-colors" />
    <div className="absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform peer-checked:translate-x-5" />
  </label>
);

const PasswordInput = ({ value, onChange, placeholder, disabled }) => {
  const [show, setShow] = useState(false);
  return (
    <div className="relative">
      <input
        type={show ? "text" : "password"}
        value={value}
        onChange={onChange}
        placeholder={placeholder}
        disabled={disabled}
        className="w-full px-4 py-2.5 pr-10 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-pink-500/20 focus:border-pink-500 placeholder-gray-400 dark:placeholder-gray-600 transition-all disabled:opacity-50"
      />
      <button
        type="button"
        onClick={() => setShow(v => !v)}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
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
    const next = [...digits];
    next[i] = d;
    onChange(next.join(""));
    if (d && i < length - 1) inputs.current[i + 1]?.focus();
  };
  const handlePaste = (e) => {
    const paste = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, length);
    onChange(paste.padEnd(length, "").slice(0, length));
    inputs.current[Math.min(paste.length, length - 1)]?.focus();
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
          className="w-11 h-12 text-center text-lg font-bold rounded-xl border-2 border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-gray-900 dark:text-white focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 outline-none transition-all"
        />
      ))}
    </div>
  );
};

const AlertBanner = ({ type, msg }) => {
  if (!msg) return null;
  const isSuccess = type === "success";
  return (
    <div className={`flex items-center gap-2 px-4 py-3 rounded-xl text-sm font-semibold mb-4 border ${
      isSuccess
        ? "bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-700 dark:text-green-400"
        : "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-600 dark:text-red-400"
    }`}>
      {isSuccess ? <CheckCircle2 size={15} /> : <AlertCircle size={15} />}
      {msg}
    </div>
  );
};

// ── 2FA Modal ────────────────────────────────────────────────────────────────
const TwoFAModal = ({ mode, email, userId, onClose, onDone }) => {
  const [step, setStep] = useState(1);
  const [otp, setOtp] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [resendCooldown, setResendCooldown] = useState(0);

  useEffect(() => {
    if (resendCooldown > 0) {
      const t = setTimeout(() => setResendCooldown(c => c - 1), 1000);
      return () => clearTimeout(t);
    }
  }, [resendCooldown]);

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
      setStep(2);
      setResendCooldown(60);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const verifyOtp = async () => {
    if (otp.length < 6) { setError("Please enter all 6 digits."); return; }
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
      setSuccess(mode === "enable" ? "2FA enabled successfully!" : "2FA disabled successfully!");
      setTimeout(() => { onDone(mode === "enable"); }, 1500);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-6 relative">
        <button onClick={onClose} className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
          <X size={18} />
        </button>

        <div className="flex items-center gap-3 mb-5">
          <div className={`p-2 rounded-xl ${mode === "enable" ? "bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600" : "bg-red-50 dark:bg-red-900/20 text-red-500"}`}>
            <Shield size={20} />
          </div>
          <div>
            <h3 className="font-bold text-gray-900 dark:text-white">
              {mode === "enable" ? "Enable 2FA" : "Disable 2FA"}
            </h3>
            <p className="text-xs text-gray-500">{email}</p>
          </div>
        </div>

        <AlertBanner type="success" msg={success} />
        <AlertBanner type="error" msg={error} />

        {step === 1 && (
          <>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-5">
              {mode === "enable"
                ? "We'll send a verification code to your email to confirm enabling two-factor authentication."
                : "To disable 2FA, we need to verify your identity first. A code will be sent to your email."}
            </p>
            <button
              onClick={sendOtp}
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 text-white font-bold hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading ? <><Loader2 size={15} className="animate-spin" /> Sending…</> : <><Mail size={15} /> Send Verification Code</>}
            </button>
          </>
        )}

        {step === 2 && (
          <>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-5 text-center">
              Enter the 6-digit code sent to your email
            </p>
            <div className="mb-5">
              <OtpInput value={otp} onChange={setOtp} />
            </div>
            <button
              onClick={verifyOtp}
              disabled={loading || otp.length < 6}
              className="w-full py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 text-white font-bold hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60 mb-3"
            >
              {loading ? <><Loader2 size={15} className="animate-spin" /> Verifying…</> : "Verify & Confirm"}
            </button>
            <button
              onClick={() => { setOtp(""); sendOtp(); }}
              disabled={resendCooldown > 0 || loading}
              className="w-full py-2 rounded-xl border border-gray-200 dark:border-gray-800 text-sm text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors flex items-center justify-center gap-2 disabled:opacity-50"
            >
              <RefreshCw size={13} />
              {resendCooldown > 0 ? `Resend in ${resendCooldown}s` : "Resend Code"}
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

  const sendResetLink = async () => {
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
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const resetPassword = async () => {
    if (!token.trim()) { setError("Please enter the reset token from your email."); return; }
    if (!newPass.trim() || newPass.length < 6) { setError("Password must be at least 6 characters."); return; }
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
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 p-6 relative">
        <button onClick={onClose} className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
          <X size={18} />
        </button>

        <div className="flex items-center gap-3 mb-5">
          <div className="p-2 rounded-xl bg-blue-50 dark:bg-blue-900/20 text-blue-600">
            <KeyRound size={20} />
          </div>
          <div>
            <h3 className="font-bold text-gray-900 dark:text-white">Reset Password</h3>
            <p className="text-xs text-gray-500">via email link</p>
          </div>
        </div>

        <AlertBanner type="error" msg={error} />

        {step === 1 && (
          <>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">A password reset link will be sent to:</p>
            <div className="px-4 py-3 rounded-xl bg-gray-50 dark:bg-gray-800 text-sm font-semibold text-gray-900 dark:text-white mb-5 break-all">
              {email}
            </div>
            <button
              onClick={sendResetLink}
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-bold hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading ? <><Loader2 size={15} className="animate-spin" /> Sending…</> : <><Mail size={15} /> Send Reset Link</>}
            </button>
          </>
        )}

        {step === 2 && (
          <>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Check your email for the reset token, then enter it below with your new password.
            </p>
            <div className="space-y-3 mb-4">
              <input
                type="text"
                value={token}
                onChange={e => setToken(e.target.value)}
                placeholder="Paste reset token from email"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 placeholder-gray-400 dark:placeholder-gray-600 transition-all"
              />
              <PasswordInput value={newPass} onChange={e => setNewPass(e.target.value)} placeholder="New Password" />
              <PasswordInput value={confirmPass} onChange={e => setConfirmPass(e.target.value)} placeholder="Confirm New Password" />
            </div>
            <button
              onClick={resetPassword}
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-bold hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading ? <><Loader2 size={15} className="animate-spin" /> Resetting…</> : "Reset Password"}
            </button>
          </>
        )}

        {step === 3 && (
          <div className="text-center py-4">
            <div className="w-14 h-14 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center mx-auto mb-3">
              <CheckCircle2 className="w-7 h-7 text-green-500" />
            </div>
            <h4 className="font-bold text-gray-900 dark:text-white mb-1">Password Reset!</h4>
            <p className="text-sm text-gray-500 mb-4">Your password has been updated successfully.</p>
            <button
              onClick={onClose}
              className="px-6 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-bold text-sm hover:opacity-90 transition-opacity"
            >
              Done
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

// ── Main Vendor Settings Component ───────────────────────────────────────────
export default function Settings() {
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;
  const userEmail = userObject?.email || "";

  const [passwords, setPasswords] = useState({ current: "", newPass: "", confirm: "" });
  const [pwdLoading, setPwdLoading] = useState(false);
  const [pwdSuccess, setPwdSuccess] = useState("");
  const [pwdError, setPwdError] = useState("");

  const [twoFAEnabled, setTwoFAEnabled] = useState(!!userObject?.twoFA?.enabled);
  const [twoFAModal, setTwoFAModal] = useState(null);
  const [showResetModal, setShowResetModal] = useState(false);

  const [emailAlerts, setEmailAlerts] = useState(true);
  const [smsAlerts, setSmsAlerts] = useState(false);
  const [subUserEmail, setSubUserEmail] = useState("");
  const [role, setRole] = useState("viewer");

  useEffect(() => {
    setTwoFAEnabled(!!userObject?.twoFA?.enabled);
  }, [userObject?.twoFA?.enabled]);

  const handleChangePassword = async () => {
    setPwdError(""); setPwdSuccess("");
    if (!passwords.current.trim()) { setPwdError("Current password is required."); return; }
    if (!passwords.newPass.trim()) { setPwdError("New password is required."); return; }
    if (passwords.newPass.length < 6) { setPwdError("New password must be at least 6 characters."); return; }
    if (passwords.newPass !== passwords.confirm) { setPwdError("New passwords do not match."); return; }
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
        setPwdSuccess("Password updated successfully!");
        setPasswords({ current: "", newPass: "", confirm: "" });
        setTimeout(() => setPwdSuccess(""), 4000);
      } else {
        setPwdError(data?.message || data?.error || "Failed to update password.");
      }
    } catch {
      setPwdError("Network error. Please check your connection.");
    } finally {
      setPwdLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8 space-y-8">
        <div>
          <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
              Settings
            </span>
          </h1>
          <p className="text-gray-500 dark:text-gray-400">Manage account security, permissions, and communications.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Change Password */}
          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center gap-3 mb-5">
              <div className="p-2 rounded-lg bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400">
                <Lock className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Change Password</h3>
            </div>

            <AlertBanner type="success" msg={pwdSuccess} />
            <AlertBanner type="error" msg={pwdError} />

            <div className="space-y-3">
              <PasswordInput value={passwords.current} onChange={e => setPasswords({ ...passwords, current: e.target.value })} placeholder="Current Password" />
              <PasswordInput value={passwords.newPass} onChange={e => setPasswords({ ...passwords, newPass: e.target.value })} placeholder="New Password" />
              <PasswordInput value={passwords.confirm} onChange={e => setPasswords({ ...passwords, confirm: e.target.value })} placeholder="Confirm New Password" />

              {passwords.newPass && (
                <div className="flex items-center gap-2">
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
                className="w-full mt-2 py-2.5 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white font-bold hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20 disabled:opacity-60 flex items-center justify-center gap-2"
              >
                {pwdLoading ? <><Loader2 size={15} className="animate-spin" /> Updating…</> : "Update Password"}
              </button>

              <button
                onClick={() => setShowResetModal(true)}
                className="w-full py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 text-sm text-gray-600 dark:text-gray-400 font-semibold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors flex items-center justify-center gap-2"
              >
                <KeyRound size={14} />
                Reset via Email Link
              </button>
            </div>
          </div>

          {/* Two-Factor Authentication */}
          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center gap-3 mb-5">
              <div className="p-2 rounded-lg bg-emerald-50 text-emerald-600 dark:bg-emerald-900/20 dark:text-emerald-400">
                <ShieldCheck className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Two-Factor Authentication</h3>
            </div>

            <div className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold mb-4 ${
              twoFAEnabled
                ? "bg-emerald-50 text-emerald-600 dark:bg-emerald-900/20 dark:text-emerald-400"
                : "bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400"
            }`}>
              <div className={`w-1.5 h-1.5 rounded-full ${twoFAEnabled ? "bg-emerald-500" : "bg-gray-400"}`} />
              {twoFAEnabled ? "Enabled" : "Disabled"}
            </div>

            <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-gray-800 mb-3">
              <div>
                <div className="font-semibold text-gray-900 dark:text-white">Email OTP</div>
                <div className="text-sm text-gray-500">Verify with a code sent to your email on each login.</div>
              </div>
              <Toggle checked={twoFAEnabled} onChange={() => setTwoFAModal(twoFAEnabled ? "disable" : "enable")} />
            </div>

            {twoFAEnabled ? (
              <div className="flex items-start gap-2 p-3 rounded-xl bg-emerald-50 dark:bg-emerald-900/10 border border-emerald-100 dark:border-emerald-900/30">
                <Smartphone size={14} className="text-emerald-600 mt-0.5 shrink-0" />
                <p className="text-xs text-emerald-700 dark:text-emerald-400">
                  2FA is active. You'll be asked for an OTP every time you log in.
                </p>
              </div>
            ) : (
              <p className="text-xs text-gray-500">
                Enable 2FA to add an extra layer of security to your vendor account.
              </p>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Add Sub Users */}
          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center gap-3 mb-5">
              <div className="p-2 rounded-lg bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400">
                <UserPlus className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Add Sub Users</h3>
            </div>
            <div className="flex gap-2">
              <input
                type="email"
                value={subUserEmail}
                onChange={e => setSubUserEmail(e.target.value)}
                placeholder="user@company.com"
                className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-purple-500/20 placeholder-gray-400 dark:placeholder-gray-600"
              />
              <button className="px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 font-bold text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Invite
              </button>
            </div>
            <div className="mt-5">
              <div className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Assign Role</div>
              <div className="grid grid-cols-3 gap-3">
                {["Viewer", "Editor", "Admin"].map(r => (
                  <button
                    key={r}
                    onClick={() => setRole(r.toLowerCase())}
                    className={`p-3 rounded-xl border text-sm font-semibold transition-all ${role === r.toLowerCase() ? "border-gray-900 dark:border-white bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white" : "border-gray-200 dark:border-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"}`}
                  >
                    {r}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Communication Preferences */}
          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center gap-3 mb-5">
              <div className="p-2 rounded-lg bg-amber-50 text-amber-600 dark:bg-amber-900/20 dark:text-amber-400">
                <UserCog className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Communication Preferences</h3>
            </div>
            <div className="space-y-3">
              <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-gray-800">
                <div className="flex items-center gap-3">
                  <Mail className="w-4 h-4 text-gray-500" />
                  <div>
                    <div className="font-semibold text-gray-900 dark:text-white text-sm">Email Alerts</div>
                    <div className="text-xs text-gray-500">Receive updates and campaign notifications.</div>
                  </div>
                </div>
                <Toggle checked={emailAlerts} onChange={e => setEmailAlerts(e.target.checked)} />
              </div>
              <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-gray-800">
                <div className="flex items-center gap-3">
                  <MessageSquare className="w-4 h-4 text-gray-500" />
                  <div>
                    <div className="font-semibold text-gray-900 dark:text-white text-sm">SMS Alerts</div>
                    <div className="text-xs text-gray-500">Get important notifications on your phone.</div>
                  </div>
                </div>
                <Toggle checked={smsAlerts} onChange={e => setSmsAlerts(e.target.checked)} />
              </div>
            </div>
          </div>
        </div>
      </div>

      {twoFAModal && (
        <TwoFAModal
          mode={twoFAModal}
          email={userEmail}
          userId={userId}
          onClose={() => setTwoFAModal(null)}
          onDone={async (enabled) => {
            setTwoFAEnabled(enabled);
            setTwoFAModal(null);
            await dispatch(fetchMe());
          }}
        />
      )}
      {showResetModal && (
        <ResetPasswordModal
          email={userEmail}
          onClose={() => setShowResetModal(false)}
        />
      )}
    </div>
  );
}
