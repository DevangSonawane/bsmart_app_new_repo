import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { ArrowLeft, Mail, ShieldCheck, Lock, CheckCircle, Search, AlertCircle } from 'lucide-react';

const ForgotPassword = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Step 1: Account Search by Email
  const [email, setEmail] = useState('');
  const [foundUser, setFoundUser] = useState(null);

  // Step 2: OTP
  const [otp, setOtp] = useState('');

  // Step 3: New Password
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  // --- Step 1 Handler: Find User by Email ---
  const handleFindAccount = async (e, shouldSendEmail = true) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Search for user in the 'users' table by email
      const { data, error } = await supabase
        .from('users')
        .select('id, email, full_name, username, avatar_url')
        .eq('email', email)
        .single();

      if (error || !data) {
        throw new Error('No account found with this email address');
      }

      setFoundUser(data);

      if (shouldSendEmail) {
        // Trigger password reset email (which contains the code/token)
        const { error: resetError } = await supabase.auth.resetPasswordForEmail(data.email);
        if (resetError) {
          // If rate limited, we still move to step 2 but warn the user
          if (resetError.status === 429 || resetError.code === 'over_email_send_rate_limit' || resetError.message?.includes('rate limit')) {
            setError('Email rate limit reached. Please use the code you received previously.');
          } else {
            throw resetError;
          }
        }
      }

      setStep(2);
    } catch (err) {
      setError(err.message || 'Account not found');
    } finally {
      setLoading(false);
    }
  };

  // --- Step 2 Handler: Verify OTP ---
  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Verify the OTP token for recovery
      const { data, error } = await supabase.auth.verifyOtp({
        email: foundUser.email,
        token: otp,
        type: 'recovery'
      });

      if (error) throw error;

      // If successful, we have a session, move to password reset
      if (data.session) {
        setStep(3);
      } else {
        throw new Error('Verification failed. Please try again.');
      }
    } catch (err) {
      setError(err.message || 'Invalid code');
    } finally {
      setLoading(false);
    }
  };

  // --- Step 3 Handler: Reset Password ---
  const handleResetPassword = async (e) => {
    e.preventDefault();
    setError('');

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);

    try {
      const { error } = await supabase.auth.updateUser({
        password: password
      });

      if (error) throw error;

      // Success! Redirect to login
      navigate('/login', { state: { message: 'Password updated successfully! Please log in.' } });
    } catch (err) {
      setError(err.message || 'Failed to update password');
    } finally {
      setLoading(false);
    }
  };

  // Render Helpers
  const renderStep1 = () => (
    <div className="space-y-6">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">Find Your Account</h1>
        <p className="text-gray-500 dark:text-gray-400">Enter your email address to search for your account.</p>
      </div>

      <form onSubmit={(e) => handleFindAccount(e, true)} className="space-y-5">
        <div className="space-y-1">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Email Address</label>
          <div className="relative group">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
              <Mail size={20} />
            </div>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full pl-10 pr-4 py-3 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
              placeholder="Enter your email"
              required
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white py-3.5 rounded-xl font-bold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none flex items-center justify-center gap-2"
        >
          {loading ? (
            <span className="flex items-center justify-center">
              <svg className="animate-spin -ml-1 mr-2 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Searching...
            </span>
          ) : (
            <>
              <Search size={20} />
              Find Account
            </>
          )}
        </button>

      </form>
    </div>
  );

  const renderStep2 = () => (
    <div className="space-y-6">
      <div className="text-center">
        <div className="w-20 h-20 bg-pink-50 dark:bg-gray-800 rounded-full flex items-center justify-center mx-auto mb-6 shadow-sm">
          <ShieldCheck size={40} className="text-insta-pink" />
        </div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">Verify it's you</h1>
        <p className="text-gray-500 dark:text-gray-400">
          We sent a code to <span className="font-medium text-gray-900 dark:text-white">{email}</span>
        </p>

        {foundUser && (
          <div className="mt-8 p-4 bg-gray-50 dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 flex items-center gap-4 text-left shadow-sm">
            <div className="w-12 h-12 bg-white dark:bg-gray-800 rounded-full flex items-center justify-center overflow-hidden border border-gray-100 dark:border-gray-800 shadow-sm shrink-0">
              {foundUser.avatar_url ? (
                <img src={foundUser.avatar_url} alt={foundUser.username} className="w-full h-full object-cover" />
              ) : (
                <span className="text-gray-500 dark:text-gray-400 font-bold text-lg">{foundUser.username?.[0]?.toUpperCase() || 'U'}</span>
              )}
            </div>
            <div className="overflow-hidden">
              <p className="font-bold text-gray-900 dark:text-white truncate">{foundUser.full_name || foundUser.username}</p>
              <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{foundUser.email}</p>
            </div>
            <div className="ml-auto">
              <CheckCircle size={20} className="text-green-500" />
            </div>
          </div>
        )}
      </div>

      <form onSubmit={handleVerifyOtp} className="space-y-6">
        <div className="space-y-2">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Verification Code</label>
          <input
            type="text"
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            className="w-full px-4 py-4 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all text-center tracking-[0.5em] font-mono text-2xl placeholder:tracking-normal dark:text-white"
            placeholder="000000"
            maxLength={6}
            required
            autoFocus
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white py-3.5 rounded-xl font-bold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none"
        >
          {loading ? 'Verifying...' : 'Verify Code'}
        </button>
      </form>
    </div>
  );

  const renderStep3 = () => (
    <div className="space-y-6">
      <div className="text-center">
        <div className="w-20 h-20 bg-green-50 dark:bg-green-900/20 rounded-full flex items-center justify-center mx-auto mb-6 shadow-sm">
          <CheckCircle size={40} className="text-green-500" />
        </div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">Reset Password</h1>
        <p className="text-gray-500 dark:text-gray-400">Create a new strong password for your account.</p>
      </div>

      <form onSubmit={handleResetPassword} className="space-y-5">
        <div className="space-y-1">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">New Password</label>
          <div className="relative group">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
              <Lock size={20} />
            </div>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full pl-10 pr-4 py-3 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
              placeholder="New password"
              required
              minLength={6}
            />
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Confirm Password</label>
          <div className="relative group">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
              <Lock size={20} />
            </div>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="w-full pl-10 pr-4 py-3 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
              placeholder="Confirm new password"
              required
              minLength={6}
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white py-3.5 rounded-xl font-bold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none"
        >
          {loading ? 'Updating...' : 'Update Password'}
        </button>
      </form>
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <Link to="/login" className="flex items-center justify-center text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors mb-8 group w-fit mx-auto">
          <div className="w-8 h-8 rounded-full bg-white dark:bg-gray-900 shadow-sm flex items-center justify-center mr-2 group-hover:-translate-x-1 transition-transform">
            <ArrowLeft size={16} />
          </div>
          <span className="font-medium">Back to Login</span>
        </Link>

        <div className="bg-white dark:bg-black py-8 px-4 shadow-xl rounded-2xl sm:px-10 border border-gray-100 dark:border-gray-800 relative overflow-hidden">
          {/* Progress Bar */}
          <div className="absolute top-0 left-0 w-full h-1.5 bg-gray-100 dark:bg-gray-800">
            <div
              className="h-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-all duration-500 ease-out"
              style={{ width: `${(step / 3) * 100}%` }}
            />
          </div>

          <div className="mt-6">
            {error && (
              <div className="mb-6 p-4 bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 rounded-xl text-sm border border-red-100 dark:border-red-800 flex items-start animate-fade-in">
                <AlertCircle className="w-5 h-5 mr-2 flex-shrink-0 mt-0.5" />
                <span>{error}</span>
              </div>
            )}

            {step === 1 && renderStep1()}
            {step === 2 && renderStep2()}
            {step === 3 && renderStep3()}
          </div>
        </div>

        <p className="mt-8 text-center text-sm text-gray-500 dark:text-gray-400">
          &copy; {new Date().getFullYear()} b_smart. All rights reserved.
        </p>
      </div>
    </div>
  );
};

export default ForgotPassword;
