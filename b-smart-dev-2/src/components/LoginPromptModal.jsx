import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock } from 'lucide-react';

// Shown to guests when they've hit the preview limit on a guest-viewable page
// (Home / Reels / Promote) or tried an action that requires an account.
const LoginPromptModal = ({
  open,
  onClose,
  title = 'Join b_smart',
  message = "Log in or create an account to keep browsing, like, comment, and connect.",
}) => {
  const navigate = useNavigate();
  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[140] flex items-center justify-center bg-black/70 px-4 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-sm rounded-3xl border border-gray-100 dark:border-white/10 bg-white dark:bg-[#171b2a] p-6 shadow-2xl text-center"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-4 right-4 w-8 h-8 rounded-full flex items-center justify-center text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-white/10 transition-colors"
        >
          ✕
        </button>

        <div className="w-14 h-14 mx-auto mb-4 rounded-2xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange flex items-center justify-center shadow-lg shadow-insta-pink/30">
          <Lock size={26} className="text-white" />
        </div>

        <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">{title}</h3>
        <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">{message}</p>

        <button
          type="button"
          onClick={() => navigate('/login')}
          className="w-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white py-3 rounded-xl font-bold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:scale-[1.02] active:scale-[0.98] transition-all mb-3"
        >
          Log In
        </button>
        <button
          type="button"
          onClick={() => navigate('/signup')}
          className="w-full py-3 rounded-xl font-semibold border border-gray-200 dark:border-gray-800 text-gray-700 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-800 transition-all"
        >
          Create an account
        </button>
      </div>
    </div>
  );
};

export default LoginPromptModal;
