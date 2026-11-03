import { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { AlertCircle, Loader2, Sparkles } from 'lucide-react';
import listingSubscriptionService from '../services/listingSubscriptionService';

const daysLeft = (dateStr) => {
  if (!dateStr) return 0;
  const diff = new Date(dateStr).getTime() - Date.now();
  return Math.max(0, Math.ceil(diff / (24 * 60 * 60 * 1000)));
};

// Shown on an influencer's own profile — their store subscription status
// (trial countdown / next billing date / payment-failed warning), with an
// "Upgrade now" shortcut to skip the rest of a free trial. Renders nothing
// for non-influencers or while there's no subscription to show.
export default function StoreSubscriptionCard() {
  const currentUser = useSelector((state) => state.auth.userObject);
  const [subscription, setSubscription] = useState(null);
  const [loading, setLoading] = useState(true);
  const [upgrading, setUpgrading] = useState(false);
  const [error, setError] = useState('');

  const isInfluencer = currentUser?.role === 'influencer';

  const load = async () => {
    try {
      const sub = await listingSubscriptionService.getMyAccountSubscription();
      setSubscription(sub);
    } catch {
      setSubscription(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!isInfluencer) {
      setLoading(false);
      return;
    }
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isInfluencer]);

  if (!isInfluencer || loading || !subscription) return null;

  const upgrade = async () => {
    setError('');
    setUpgrading(true);
    try {
      const result = await listingSubscriptionService.upgradeAccountSubscription();
      const razorpay = result?.razorpay;
      if (!razorpay?.subscription_id || !razorpay?.key_id) {
        throw new Error('Subscription details were not returned.');
      }
      const loaded = await listingSubscriptionService.loadRazorpay();
      if (!loaded) throw new Error('Payment gateway failed to load. Please try again.');

      const rzp = new window.Razorpay({
        key: razorpay.key_id,
        subscription_id: razorpay.subscription_id,
        name: 'BSmart',
        description: 'Upgrade your store subscription',
        prefill: {
          name: currentUser?.full_name || currentUser?.name || '',
          contact: currentUser?.phone || '',
          email: currentUser?.email || '',
        },
        theme: { color: '#fa3f5e' },
        handler: async () => {
          await load();
          setUpgrading(false);
        },
        modal: { ondismiss: () => setUpgrading(false) },
      });
      rzp.on('payment.failed', (response) => {
        setError(response?.error?.description || 'Payment authorization failed. Please try again.');
        setUpgrading(false);
      });
      rzp.open();
    } catch (err) {
      setError(err?.response?.data?.message || err.message || 'Could not upgrade right now.');
      setUpgrading(false);
    }
  };

  if (subscription.status === 'trialing') {
    const remaining = daysLeft(subscription.trial_ends_at);
    return (
      <div className="bg-white dark:bg-gray-900 border border-[#fa3f5e]/30 rounded-2xl shadow-sm p-4 space-y-2">
        <div className="flex items-center gap-2">
          <Sparkles size={16} className="text-[#fa3f5e]" />
          <p className="text-sm font-bold text-gray-900 dark:text-white">
            Free trial — {remaining} day{remaining === 1 ? '' : 's'} left
          </p>
        </div>
        <p className="text-xs text-gray-500 dark:text-gray-400">
          Then ₹99/month, auto-renewing. Upgrade now to skip the wait, or cancel anytime from here.
        </p>
        {error && <p role="alert" className="text-xs text-red-500">{error}</p>}
        <button
          type="button"
          onClick={upgrade}
          disabled={upgrading}
          className="w-full py-2 rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white text-xs font-bold disabled:opacity-60 flex items-center justify-center gap-1.5"
        >
          {upgrading ? <><Loader2 size={13} className="animate-spin" />Processing…</> : 'Upgrade now — ₹99/mo'}
        </button>
      </div>
    );
  }

  if (subscription.status === 'active') {
    const renewDate = subscription.current_period_end
      ? new Date(subscription.current_period_end).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
      : null;
    return (
      <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm p-4">
        <p className="text-sm font-bold text-gray-900 dark:text-white">Store subscription active</p>
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">₹99/month{renewDate ? ` · renews ${renewDate}` : ''}</p>
      </div>
    );
  }

  if (subscription.status === 'past_due') {
    return (
      <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-2xl shadow-sm p-4 flex items-start gap-2">
        <AlertCircle size={16} className="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-bold text-amber-800 dark:text-amber-300">Payment failed</p>
          <p className="text-xs text-amber-700 dark:text-amber-400 mt-1">
            We couldn't renew your subscription. Razorpay is retrying automatically — update your payment method if this continues.
          </p>
        </div>
      </div>
    );
  }

  return null;
}
