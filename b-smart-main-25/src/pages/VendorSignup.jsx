import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../lib/api';
import {
  User, Mail, Phone, Lock, Building2, Briefcase, Sparkles,
  CalendarDays, ArrowLeft, ArrowRight, Eye, EyeOff,
  CheckCircle2, XCircle, Loader2
} from 'lucide-react';

const VendorSignup = () => {
  const navigate = useNavigate();

  const [step, setStep] = useState(1);
  const [error, setError] = useState('');
  const [completed, setCompleted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [form, setForm] = useState({
    name: '', username: '', email: '', phone: '',
    password: '', confirmPassword: '',
    companyName: '', companyLegalName: '', industry: '',
    registrationNumber: '', taxId: '', yearEstablished: '', companyType: ''
  });

  // ── Field availability checks ─────────────────────────────────────────────
  const [checks, setChecks] = useState({ email: null, username: null, phone: null });
  const [checkLoading, setCheckLoading] = useState({ email: false, username: false, phone: false });

  const checkField = async (field, value) => {
    if (!value.trim()) return;
    setCheckLoading(p => ({ ...p, [field]: true }));
    try {
      await api.post(`/users/check/${field}`, { [field]: value.trim() });
      setChecks(p => ({ ...p, [field]: true }));
    } catch {
      setChecks(p => ({ ...p, [field]: false }));
    } finally {
      setCheckLoading(p => ({ ...p, [field]: false }));
    }
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
    if (['email', 'username', 'phone'].includes(name)) {
      setChecks(p => ({ ...p, [name]: null }));
    }
  };

  const FieldStatus = ({ field }) => {
    if (checkLoading[field]) return <Loader2 size={16} className="animate-spin text-gray-400" />;
    if (checks[field] === true) return <CheckCircle2 size={16} className="text-green-500" />;
    if (checks[field] === false) return <XCircle size={16} className="text-red-500" />;
    return null;
  };

  const fieldMsg = (field) => {
    if (checks[field] === false) {
      return { email: 'Email already registered.', username: 'Username already taken.', phone: 'Phone already registered.' }[field];
    }
    if (checks[field] === true) {
      return { email: 'Email available.', username: 'Username available.', phone: 'Phone available.' }[field];
    }
    return null;
  };

  const inputCls = (field) =>
    `w-full pl-10 pr-10 py-2.5 bg-gray-50 dark:bg-gray-900 border rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white ${
      checks[field] === false ? 'border-red-400 dark:border-red-500' :
      checks[field] === true  ? 'border-green-400 dark:border-green-500' :
      'border-gray-200 dark:border-gray-800'
    }`;

  const validateStep = () => {
    if (step === 1) {
      if (!form.name || !form.username || !form.email || !form.phone || !form.password || !form.confirmPassword) {
        setError('Please fill in all required fields.'); return false;
      }
      if (form.password !== form.confirmPassword) {
        setError('Passwords do not match.'); return false;
      }
      if (checks.email === false || checks.username === false || checks.phone === false) {
        setError('Please fix the field errors before continuing.'); return false;
      }
    }
    if (step === 2) {
      if (!form.companyName || !form.companyLegalName || !form.industry || !form.registrationNumber || !form.taxId || !form.yearEstablished || !form.companyType) {
        setError('Please complete the key company details.'); return false;
      }
    }
    setError(''); return true;
  };

  const handleNext = () => { if (!validateStep()) return; setStep(p => Math.min(p + 1, 2)); };
  const handleBack = () => { setError(''); setStep(p => Math.max(p - 1, 1)); };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validateStep()) return;
    setError(''); setCompleted(false); setLoading(true);
    const payload = {
      email: form.email, password: form.password, username: form.username,
      full_name: form.name, phone: form.phone, role: 'vendor',
      company_details: {
        company_name: form.companyName, "Registered Name": form.companyLegalName,
        industry: form.industry, "Registration Number": form.registrationNumber,
        "Tax ID / VAT / GST": form.taxId, "Year Established": form.yearEstablished,
        "Company Type": form.companyType
      },
      credits: 200000,
    };
    try {
      await api.post('/auth/register', payload);
      setCompleted(true); navigate('/login');
    } catch (err) {
      setError(err.response?.data?.message || 'Something went wrong.');
    } finally { setLoading(false); }
  };

  const steps = [{ id: 1, label: 'Account' }, { id: 2, label: 'Business' }];
  const progress = (step / 2) * 100;

  const renderStep = () => {
    if (step === 1) {
      return (
        <div className="space-y-4">
          {/* Full Name */}
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Full Name</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><User size={18} /></div>
              <input name="name" value={form.name} onChange={handleChange} placeholder="John Founder"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                required />
            </div>
          </div>

          {/* Email */}
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Email Address</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Mail size={18} /></div>
              <input name="email" type="email" value={form.email} onChange={handleChange}
                onBlur={() => checkField('email', form.email)}
                placeholder="founder@company.com" className={inputCls('email')} required />
              <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none"><FieldStatus field="email" /></div>
            </div>
            {fieldMsg('email') && <p className={`text-xs ml-1 ${checks.email === false ? 'text-red-500' : 'text-green-600'}`}>{fieldMsg('email')}</p>}
          </div>

          {/* Phone */}
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Phone Number</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Phone size={18} /></div>
              <input name="phone" value={form.phone} onChange={handleChange}
                onBlur={() => checkField('phone', form.phone)}
                placeholder="+1 234 567 890" className={inputCls('phone')} required />
              <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none"><FieldStatus field="phone" /></div>
            </div>
            {fieldMsg('phone') && <p className={`text-xs ml-1 ${checks.phone === false ? 'text-red-500' : 'text-green-600'}`}>{fieldMsg('phone')}</p>}
          </div>

          {/* Username — above passwords */}
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Username</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><User size={18} /></div>
              <input name="username" value={form.username} onChange={handleChange}
                onBlur={() => checkField('username', form.username)}
                placeholder="brandname" className={inputCls('username')} required />
              <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none"><FieldStatus field="username" /></div>
            </div>
            {fieldMsg('username') && <p className={`text-xs ml-1 ${checks.username === false ? 'text-red-500' : 'text-green-600'}`}>{fieldMsg('username')}</p>}
          </div>

          {/* Password + Confirm */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Lock size={18} /></div>
                <input name="password" type={showPassword ? 'text' : 'password'} value={form.password} onChange={handleChange} placeholder="••••••••"
                  className="w-full pl-10 pr-10 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required />
                <button type="button" onClick={() => setShowPassword(v => !v)} className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Confirm Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Lock size={18} /></div>
                <input name="confirmPassword" type={showConfirmPassword ? 'text' : 'password'} value={form.confirmPassword} onChange={handleChange} placeholder="••••••••"
                  className="w-full pl-10 pr-10 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required />
                <button type="button" onClick={() => setShowConfirmPassword(v => !v)} className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
                  {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>
          </div>
        </div>
      );
    }

    if (step === 2) {
      return (
        <div className="space-y-4">
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Company Name</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Building2 size={18} /></div>
              <input name="companyName" value={form.companyName} onChange={handleChange} placeholder="Company or brand name"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white" required />
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Registered Name</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Briefcase size={18} /></div>
              <input name="companyLegalName" value={form.companyLegalName} onChange={handleChange} placeholder="Registered legal name"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white" required />
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Registration Number</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Building2 size={18} /></div>
                <input name="registrationNumber" value={form.registrationNumber} onChange={handleChange} placeholder="Business Reg. No."
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white" required />
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Tax ID / VAT / GST</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Building2 size={18} /></div>
                <input name="taxId" value={form.taxId} onChange={handleChange} placeholder="Tax Identification Number"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white" required />
              </div>
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Industry</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Briefcase size={18} /></div>
                <input name="industry" value={form.industry} onChange={handleChange} placeholder="Fashion, Food, Tech..."
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white" required />
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Company Type</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><Building2 size={18} /></div>
                <select name="companyType" value={form.companyType} onChange={handleChange}
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all text-gray-900 dark:text-white appearance-none" required>
                  <option value="">Select Type</option>
                  <option value="Private Limited">Private Limited</option>
                  <option value="Public Limited">Public Limited</option>
                  <option value="LLP">LLP</option>
                  <option value="Partnership">Partnership</option>
                  <option value="Sole Proprietorship">Sole Proprietorship</option>
                  <option value="NGO / Trust">NGO / Trust</option>
                </select>
              </div>
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Year Established</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors"><CalendarDays size={18} /></div>
              <input name="yearEstablished" value={form.yearEstablished} onChange={handleChange} placeholder="YYYY"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white" required />
            </div>
          </div>
        </div>
      );
    }
  };

  return (
    <div className="h-screen flex bg-white dark:bg-black overflow-hidden">
      <div className="hidden lg:flex lg:w-1/2 relative bg-insta-gradient overflow-hidden h-full">
        <div className="absolute inset-0 bg-black/10" />
        <div className="absolute inset-0 flex flex-col items-center justify-center text-white p-12 text-center z-10">
          <div className="w-24 h-24 bg-white/20 backdrop-blur-lg rounded-3xl flex items-center justify-center mb-8 shadow-xl border border-white/30">
            <Sparkles size={48} className="text-white" />
          </div>
          <h1 className="text-4xl font-bold mb-4 tracking-tight">Grow your business with b_smart</h1>
          <p className="text-lg text-white/90 max-w-md font-light leading-relaxed">
            Reach the right people, run smart campaigns and measure performance in one place.
          </p>
          <div className="mt-10 flex flex-wrap gap-3 justify-center text-sm text-white/90">
            <span className="px-3 py-1 rounded-full bg-white/15 border border-white/30">Smart audience targeting</span>
            <span className="px-3 py-1 rounded-full bg-white/15 border border-white/30">Real-time performance</span>
          </div>
          <div className="absolute -top-24 -left-24 w-64 h-64 bg-white/10 rounded-full blur-3xl" />
          <div className="absolute -bottom-32 -right-32 w-80 h-80 bg-purple-900/20 rounded-full blur-3xl" />
        </div>
      </div>

      <div className="w-full lg:w-1/2 flex flex-col px-6 sm:px-12 xl:px-24 bg-white dark:bg-black h-full overflow-y-auto scrollbar-hide">
        <div className="max-w-md w-full mx-auto py-10">
          <div className="mb-6 flex items-center justify-between">
            <Link to="/signup" className="inline-flex items-center text-gray-500 hover:text-insta-pink transition-colors group text-sm">
              <ArrowLeft size={18} className="mr-1 group-hover:-translate-x-1 transition-transform" />
              Back to user signup
            </Link>
            <Link to="/login" className="text-xs text-gray-500 hover:text-insta-pink transition-colors">Already a vendor? Log in</Link>
          </div>

          <div className="mb-6">
            <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-1">Create Vendor Account</h2>
            <p className="text-gray-500 dark:text-gray-400 text-sm">Step {step} of 2 · Set up your business profile to run Spotlights.</p>
          </div>

          <div className="mb-6">
            <div className="flex items-center justify-between mb-3">
              {steps.map((s) => (
                <div key={s.id} className="flex-1 flex flex-col items-center">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold border ${step === s.id ? 'bg-insta-pink text-white border-insta-pink' : step > s.id ? 'bg-insta-pink/10 text-insta-pink border-insta-pink/40' : 'bg-gray-100 dark:bg-gray-900 text-gray-500 dark:text-gray-400 border-gray-200 dark:border-gray-800'}`}>
                    {s.id}
                  </div>
                  <span className="mt-1 text-[11px] font-medium text-gray-500 dark:text-gray-400">{s.label}</span>
                </div>
              ))}
            </div>
            <div className="w-full h-1.5 rounded-full bg-gray-100 dark:bg-gray-900 overflow-hidden">
              <div className="h-full rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-all" style={{ width: `${progress}%` }} />
            </div>
          </div>

          <form onSubmit={step === 2 ? handleSubmit : (e) => { e.preventDefault(); handleNext(); }} className="space-y-5">
            {renderStep()}

            {error && (
              <div className="p-3 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-800 text-red-600 dark:text-red-400 text-sm flex items-center">
                <svg className="w-4 h-4 mr-2 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                {error}
              </div>
            )}

            {completed && !error && (
              <div className="p-3 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-800 text-green-600 dark:text-green-400 text-sm flex items-center">
                <svg className="w-4 h-4 mr-2 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Vendor signup steps completed.
              </div>
            )}

            <div className="flex items-center justify-between pt-2">
              <button type="button" onClick={handleBack} disabled={step === 1}
                className="inline-flex items-center text-sm px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 disabled:opacity-50 disabled:cursor-not-allowed">
                <ArrowLeft size={16} className="mr-1" /> Back
              </button>
              {step < 2 && (
                <button type="submit" className="inline-flex items-center px-5 py-2.5 rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white text-sm font-semibold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all">
                  Next <ArrowRight size={16} className="ml-2" />
                </button>
              )}
              {step === 2 && (
                <button type="submit" disabled={loading} className="inline-flex items-center px-5 py-2.5 rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white text-sm font-semibold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none">
                  {loading ? 'Submitting...' : 'Complete vendor signup'} <ArrowRight size={16} className="ml-2" />
                </button>
              )}
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default VendorSignup;
