import React, { useState } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { ShieldCheck, ArrowLeft, Loader2 } from 'lucide-react';

const VerifyOtp = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const [email, setEmail] = useState(location.state?.email || '');
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const handleVerify = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setLoading(true);

    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email,
        token: otp,
        type: 'signup'
      });

      if (error) throw error;

      // If verification is successful, data.session will be present
      if (data.session) {
        navigate('/');
      } else {
        // Sometimes session is not immediately available or configured differently
        navigate('/login', { state: { message: 'Email verified successfully! Please log in.' } });
      }
    } catch (err) {
      setError(err.message || 'Invalid OTP code');
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (!email) return;
    setResending(true);
    setError('');
    setMessage('');

    try {
      const { error } = await supabase.auth.resend({
        type: 'signup',
        email
      });

      if (error) throw error;
      setMessage('Verification code resent successfully!');
    } catch (err) {
      setError(err.message || 'Failed to resend code');
    } finally {
      setResending(false);
    }
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col px-6 py-8 transition-colors duration-200">
      <Link to="/signup" className="inline-flex items-center text-gray-500 dark:text-gray-400 mb-8 hover:text-gray-900 dark:hover:text-white transition-colors">
        <ArrowLeft size={20} className="mr-2" />
        Back to Signup
      </Link>

      <div className="flex-1 flex flex-col justify-center max-w-sm mx-auto w-full">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-pink-50 dark:bg-gray-900 rounded-full flex items-center justify-center mx-auto mb-4 text-[#fa3f5e]">
            <ShieldCheck size={32} />
          </div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">Verify your email</h1>
          <p className="text-gray-500 dark:text-gray-400">
            Please enter the verification code sent to
            <br />
            <span className="font-medium text-gray-900 dark:text-white">{email || 'your email'}</span>
          </p>
        </div>

        {message && (
          <div className="mb-6 p-4 bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400 rounded-xl text-sm border border-green-100 dark:border-green-900/30">
            {message}
          </div>
        )}

        {error && (
          <div className="mb-6 p-4 bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 rounded-xl text-sm border border-red-100 dark:border-red-900/30">
            {error}
          </div>
        )}

        <form onSubmit={handleVerify} className="space-y-6">
          {!location.state?.email && (
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Email Address</label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-4 py-3 rounded-xl bg-gray-50 dark:bg-gray-900 border border-gray-100 dark:border-gray-800 text-gray-900 dark:text-white focus:border-[#fa3f5e] focus:ring-1 focus:ring-[#fa3f5e] outline-none transition-all placeholder-gray-400 dark:placeholder-gray-600"
                placeholder="Enter your email"
              />
            </div>
          )}

          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Verification Code</label>
            <input
              type="text"
              required
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-gray-50 dark:bg-gray-900 border border-gray-100 dark:border-gray-800 text-gray-900 dark:text-white focus:border-[#fa3f5e] focus:ring-1 focus:ring-[#fa3f5e] outline-none transition-all text-center tracking-widest text-lg font-mono placeholder-gray-400 dark:placeholder-gray-600"
              placeholder="000000"
              maxLength={6}
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#fa3f5e] text-white py-4 rounded-xl font-semibold text-lg hover:bg-[#e63550] transition-colors disabled:opacity-70 disabled:cursor-not-allowed flex items-center justify-center"
          >
            {loading ? <Loader2 className="animate-spin" /> : 'Verify Email'}
          </button>
        </form>

        <div className="mt-8 text-center">
          <p className="text-gray-500 dark:text-gray-400 text-sm">
            Didn't receive the code?{' '}
            <button
              onClick={handleResend}
              disabled={resending || !email}
              className="text-[#fa3f5e] font-medium hover:underline disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {resending ? 'Sending...' : 'Resend'}
            </button>
          </p>
        </div>
      </div>
    </div>
  );
};

export default VerifyOtp;
