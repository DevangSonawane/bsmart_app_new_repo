import { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { Loader2, AlertCircle, Check, Sparkles, X } from 'lucide-react';
import listingSubscriptionService from '../../services/listingSubscriptionService';

// Shown on My Store when an influencer has no subscription record at all yet
// (e.g. became an influencer before this billing feature existed, so they
// never went through InfluencerSwitchModal's trial-vs-pay checkout) — offers
// the same 7-day-trial-vs-pay-now choice so they have a way to activate
// billing. Once a subscription exists, StoreSubscriptionCard takes over.
export default function SubscriptionTrialModal() {
  const currentUser = useSelector((state) => state.auth.userObject);
  const isInfluencer = currentUser?.role === 'influencer';
  const [checked, setChecked] = useState(false);
  const [needsSubscription, setNeedsSubscription] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [option, setOption] = useState(null); // 'trial' | 'now' | null
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isInfluencer) {
      setChecked(true);
      return;
    }
    let active = true;
    listingSubscriptionService.getMyAccountSubscription()
      .then((sub) => { if (active) setNeedsSubscription(!sub); })
      .catch(() => { if (active) setNeedsSubscription(false); })
      .finally(() => { if (active) setChecked(true); });
    return () => { active = false; };
  }, [isInfluencer]);

  if (!isInfluencer || !checked || !needsSubscription || dismissed) return null;

  const choosePlan = async (startTrial) => {
    setError('');
    setOption(startTrial ? 'trial' : 'now');
    try {
      const result = await listingSubscriptionService.createAccountSubscription(startTrial);
      const razorpay = result?.razorpay;
      if (!razorpay?.subscription_id || !razorpay?.key_id) throw new Error('Subscription details were not returned.');
      const loaded = await listingSubscriptionService.loadRazorpay();
      if (!loaded) throw new Error('Payment gateway failed to load. Please try again.');

      const rzp = new window.Razorpay({
        key: razorpay.key_id,
        subscription_id: razorpay.subscription_id,
        name: 'BSmart',
        description: 'Activate your store',
        prefill: {
          name: currentUser?.full_name || currentUser?.name || '',
          contact: currentUser?.phone || '',
          email: currentUser?.email || '',
        },
        theme: { color: '#fa3f5e' },
        handler: () => setDismissed(true),
        modal: { ondismiss: () => setOption(null) },
      });
      rzp.on('payment.failed', (response) => {
        setError(response?.error?.description || 'Payment authorization failed. Please try again.');
        setOption(null);
      });
      rzp.open();
    } catch (err) {
      setError(err?.response?.data?.message || err.message || 'Could not start your subscription.');
      setOption(null);
    }
  };

  return (
    <div className="fixed inset-0 z-[999] flex items-end sm:items-center justify-center">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={() => setDismissed(true)} />
      <div className="relative w-full sm:max-w-md bg-white dark:bg-gray-950 rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
          <div className="flex items-center gap-2.5">
            <span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 text-[#fa3f5e] flex items-center justify-center shrink-0">
              <Sparkles size={17} />
            </span>
            <div>
              <h2 className="text-base font-bold text-gray-900 dark:text-white leading-tight">Activate your store</h2>
              <p className="text-xs text-gray-400 dark:text-gray-500">Start selling on Marketplace with a store subscription</p>
            </div>
          </div>
          <button onClick={() => setDismissed(true)} className="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors shrink-0">
            <X size={16} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
          {error && (
            <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-xs">
              <AlertCircle size={13} className="shrink-0" /> {error}
            </div>
          )}
          <p className="text-xs text-gray-400 dark:text-gray-500">Choose how you'd like to start. You can cancel anytime from My Store.</p>

          <button
            type="button"
            onClick={() => choosePlan(true)}
            disabled={!!option}
            className="w-full text-left rounded-2xl border-2 border-[#fa3f5e] p-4 hover:bg-pink-50/50 dark:hover:bg-pink-900/10 disabled:opacity-60 transition-colors"
          >
            <div className="flex items-center gap-2">
              <Sparkles size={18} className="text-[#fa3f5e]" />
              <span className="font-bold text-gray-900 dark:text-white">7-day free trial</span>
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">
              Active today, free for 7 days. Then ₹99/month, auto-renewing — cancel anytime before it ends to avoid the charge.
            </p>
            {option === 'trial' && (
              <span className="inline-flex items-center gap-1.5 text-xs text-[#fa3f5e] mt-2">
                <Loader2 size={12} className="animate-spin" />Opening checkout…
              </span>
            )}
          </button>

          <button
            type="button"
            onClick={() => choosePlan(false)}
            disabled={!!option}
            className="w-full text-left rounded-2xl border border-gray-200 dark:border-gray-700 p-4 hover:bg-gray-50 dark:hover:bg-gray-900 disabled:opacity-60 transition-colors"
          >
            <div className="flex items-center gap-2">
              <Check size={18} className="text-gray-700 dark:text-gray-300" />
              <span className="font-bold text-gray-900 dark:text-white">Subscribe now — ₹99/mo</span>
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">
              Billed today, then every month automatically. Cancel anytime from My Store.
            </p>
            {option === 'now' && (
              <span className="inline-flex items-center gap-1.5 text-xs text-gray-500 mt-2">
                <Loader2 size={12} className="animate-spin" />Opening checkout…
              </span>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
