import { Coins, PartyPopper, X } from 'lucide-react';

// Reusable celebratory popup for a coin grant — used for the signup bonus
// (Signup.jsx) and the daily login reward (Layout.jsx). Same shell/styling
// as the other modals in the app (see InfluencerSwitchModal.jsx).
export default function CoinRewardModal({ isOpen, onClose, amount, title, message }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[999] flex items-end sm:items-center justify-center">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full sm:max-w-sm bg-white dark:bg-gray-950 rounded-t-3xl sm:rounded-2xl shadow-2xl p-6 text-center overflow-hidden">
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-3 right-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
        >
          <X size={20} />
        </button>

        <div className="mx-auto w-20 h-20 rounded-full bg-gradient-to-br from-insta-purple via-insta-pink to-insta-orange flex items-center justify-center mb-4 shadow-lg shadow-pink-500/20">
          <Coins size={36} className="text-white" />
        </div>

        <div className="flex items-center justify-center gap-1.5 text-insta-purple">
          <PartyPopper size={16} />
          <span className="text-xs font-bold uppercase tracking-widest">Reward unlocked</span>
        </div>

        <h2 className="text-xl font-bold text-gray-900 dark:text-white mt-2">{title}</h2>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">{message}</p>
        <p className="text-4xl font-extrabold text-[#fa3f5e] mt-4">+{amount.toLocaleString()} coins</p>

        <button
          type="button"
          onClick={onClose}
          className="w-full mt-6 py-3 rounded-2xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white font-bold text-sm hover:opacity-90 transition-opacity"
        >
          Awesome!
        </button>
      </div>
    </div>
  );
}
