import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Loader2, AlertCircle, Check, CheckCircle2, ChevronLeft, Sparkles, Store, X } from 'lucide-react';
import api from '../lib/api';
import { fetchMe } from '../store/authSlice';
import listingSubscriptionService from '../services/listingSubscriptionService';

const EMPTY_FORM = {
  business_type: '',
  store_name: '',
  store_description: '',
  products_type: '',
  service_type: '',
};

const listToText = (value) => {
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'string') return value;
  return '';
};

const textToList = (value) => String(value || '')
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean);

const FIELD_CLS = 'w-full px-3.5 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] placeholder-gray-400 dark:placeholder-gray-600 transition-all';
const LABEL_CLS = 'text-[11px] font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest';

// Shared "become an influencer" popup — same /users/:id/role API and fields as
// Settings > Account, reusable from anywhere (Profile, Marketplace, etc.).
const InfluencerSwitchModal = ({ isOpen, onClose }) => {
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;
  const role = userObject?.role || 'member';

  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);
  // 'form' (store details) -> 'payment' (7-day trial vs ₹99/mo choice)
  const [step, setStep] = useState('form');
  const [payingOption, setPayingOption] = useState(null); // 'trial' | 'now' | null

  useEffect(() => {
    if (!isOpen) return;
    const profile = userObject?.influencer_profile || userObject?.influencerProfile || {};
    setForm({
      business_type: profile.business_type || '',
      store_name: profile.store_name || '',
      store_description: profile.store_description || '',
      products_type: listToText(profile.products_type),
      service_type: listToText(profile.service_type),
    });
    setError('');
    setSaved(false);
    setStep('form');
    setPayingOption(null);
  }, [isOpen, userObject]);

  if (!isOpen) return null;

  const upd = (field, value) => setForm((f) => ({ ...f, [field]: value }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!userId || saving) return;

    const products = textToList(form.products_type);
    const services = textToList(form.service_type);
    const missingField = [
      ['Business type', form.business_type],
      ['Store name', form.store_name],
      ['Store description', form.store_description],
      ['Products type', products.length > 0],
      ['Service type', services.length > 0],
    ].find(([, value]) => !value);

    if (missingField) {
      setError(`${missingField[0]} is required.`);
      return;
    }

    // Store details are valid — move to the trial-vs-pay choice. The role
    // switch itself (and saving these details) only happens once Razorpay
    // confirms the subscription mandate was actually authorized, so an
    // abandoned checkout never grants influencer access for free.
    setError('');
    setStep('payment');
  };

  const choosePlan = async (startTrial) => {
    setError('');
    setPayingOption(startTrial ? 'trial' : 'now');
    try {
      const result = await listingSubscriptionService.createAccountSubscription(startTrial);
      const razorpay = result?.razorpay;
      if (!razorpay?.subscription_id || !razorpay?.key_id) {
        throw new Error('Subscription details were not returned.');
      }
      const loaded = await listingSubscriptionService.loadRazorpay();
      if (!loaded) throw new Error('Payment gateway failed to load. Please try again.');

      const products = textToList(form.products_type);
      const services = textToList(form.service_type);

      const rzp = new window.Razorpay({
        key: razorpay.key_id,
        subscription_id: razorpay.subscription_id,
        name: 'BSmart',
        description: 'Activate your store',
        prefill: {
          name: userObject?.full_name || userObject?.name || '',
          contact: userObject?.phone || '',
          email: userObject?.email || '',
        },
        theme: { color: '#fa3f5e' },
        handler: async () => {
          setSaving(true);
          try {
            await api.patch(`/users/${userId}/role`, {
              role: 'influencer',
              business_type: form.business_type.trim(),
              store_name: form.store_name.trim(),
              store_description: form.store_description.trim(),
              products_type: products,
              service_type: services,
            });
            await dispatch(fetchMe());
            setSaved(true);
          } catch (err) {
            setError(err?.response?.data?.message || 'Payment succeeded but switching your account failed. Contact support.');
          } finally {
            setSaving(false);
            setPayingOption(null);
          }
        },
        modal: { ondismiss: () => setPayingOption(null) },
      });
      rzp.on('payment.failed', (response) => {
        setError(response?.error?.description || 'Payment authorization failed. Please try again.');
        setPayingOption(null);
      });
      rzp.open();
    } catch (err) {
      setError(err?.response?.data?.message || err.message || 'Could not start your subscription.');
      setPayingOption(null);
    }
  };

  return (
    <div className="fixed inset-0 z-[999] flex items-end sm:items-center justify-center">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full sm:max-w-md bg-white dark:bg-gray-950 rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
          <div className="flex items-center gap-2.5">
            <span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 text-[#fa3f5e] flex items-center justify-center shrink-0">
              <Store size={17} />
            </span>
            <div>
              <h2 className="text-base font-bold text-gray-900 dark:text-white leading-tight">Become an Influencer</h2>
              <p className="text-xs text-gray-400 dark:text-gray-500">Set up your storefront to sell on Marketplace</p>
            </div>
          </div>
          <button onClick={onClose} className="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors shrink-0">
            <X size={16} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4">
          {role === 'influencer' ? (
            <div className="flex flex-col items-center text-center py-6 gap-3">
              <CheckCircle2 size={36} className="text-green-500" />
              <p className="text-sm font-semibold text-gray-900 dark:text-white">You're already an Influencer.</p>
              <p className="text-xs text-gray-400 dark:text-gray-500">Manage your storefront from My Store.</p>
              <Link
                to="/market/my-store"
                onClick={onClose}
                className="mt-1 px-5 py-2.5 rounded-xl bg-[#fa3f5e] text-white text-sm font-bold hover:opacity-90 transition-opacity"
              >
                Go to My Store
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-3">
              {saved ? (
                <div className="flex flex-col items-center text-center py-6 gap-3">
                  <CheckCircle2 size={36} className="text-green-500" />
                  <p className="text-sm font-semibold text-gray-900 dark:text-white">You're now an Influencer!</p>
                  <Link
                    to="/market/my-store"
                    onClick={onClose}
                    className="mt-1 px-5 py-2.5 rounded-xl bg-[#fa3f5e] text-white text-sm font-bold hover:opacity-90 transition-opacity"
                  >
                    Go to My Store
                  </Link>
                </div>
              ) : step === 'payment' ? (
                <>
                  <button
                    type="button"
                    onClick={() => setStep('form')}
                    className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                  >
                    <ChevronLeft size={14} /> Back
                  </button>
                  {error && (
                    <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-xs">
                      <AlertCircle size={13} className="shrink-0" /> {error}
                    </div>
                  )}
                  <p className="text-sm font-bold text-gray-900 dark:text-white">Activate your store</p>
                  <p className="text-xs text-gray-400 dark:text-gray-500 -mt-2">Choose how you'd like to start. You can cancel anytime from My Store.</p>

                  <button
                    type="button"
                    onClick={() => choosePlan(true)}
                    disabled={!!payingOption || saving}
                    className="w-full text-left rounded-2xl border-2 border-[#fa3f5e] p-4 hover:bg-pink-50/50 dark:hover:bg-pink-900/10 disabled:opacity-60 transition-colors"
                  >
                    <div className="flex items-center gap-2">
                      <Sparkles size={18} className="text-[#fa3f5e]" />
                      <span className="font-bold text-gray-900 dark:text-white">7-day free trial</span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">
                      Active today, free for 7 days. Then ₹99/month, auto-renewing — cancel anytime before it ends to avoid the charge.
                    </p>
                    {payingOption === 'trial' && (
                      <span className="inline-flex items-center gap-1.5 text-xs text-[#fa3f5e] mt-2">
                        <Loader2 size={12} className="animate-spin" />{saving ? 'Setting up your store…' : 'Opening checkout…'}
                      </span>
                    )}
                  </button>

                  <button
                    type="button"
                    onClick={() => choosePlan(false)}
                    disabled={!!payingOption || saving}
                    className="w-full text-left rounded-2xl border border-gray-200 dark:border-gray-700 p-4 hover:bg-gray-50 dark:hover:bg-gray-900 disabled:opacity-60 transition-colors"
                  >
                    <div className="flex items-center gap-2">
                      <Check size={18} className="text-gray-700 dark:text-gray-300" />
                      <span className="font-bold text-gray-900 dark:text-white">Subscribe now — ₹99/mo</span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-1.5">
                      Billed today, then every month automatically. Cancel anytime from My Store.
                    </p>
                    {payingOption === 'now' && (
                      <span className="inline-flex items-center gap-1.5 text-xs text-gray-500 mt-2">
                        <Loader2 size={12} className="animate-spin" />{saving ? 'Setting up your store…' : 'Opening checkout…'}
                      </span>
                    )}
                  </button>
                </>
              ) : (
                <>
                  {error && (
                    <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-xs">
                      <AlertCircle size={13} className="shrink-0" /> {error}
                    </div>
                  )}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className={LABEL_CLS}>Business Type</label>
                      <input className={`${FIELD_CLS} mt-1.5`} placeholder="Fashion" value={form.business_type} onChange={(e) => upd('business_type', e.target.value)} />
                    </div>
                    <div>
                      <label className={LABEL_CLS}>Store Name</label>
                      <input className={`${FIELD_CLS} mt-1.5`} placeholder="Aniket's Closet" value={form.store_name} onChange={(e) => upd('store_name', e.target.value)} />
                    </div>
                  </div>
                  <div>
                    <label className={LABEL_CLS}>Store Description</label>
                    <textarea className={`${FIELD_CLS} mt-1.5 resize-none`} rows={3} placeholder="Curated streetwear and accessories" value={form.store_description} onChange={(e) => upd('store_description', e.target.value)} />
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className={LABEL_CLS}>Products Type</label>
                      <input className={`${FIELD_CLS} mt-1.5`} placeholder="clothing, accessories" value={form.products_type} onChange={(e) => upd('products_type', e.target.value)} />
                      <p className="text-[11px] text-gray-400 mt-1">Separate multiple values with commas.</p>
                    </div>
                    <div>
                      <label className={LABEL_CLS}>Service Type</label>
                      <input className={`${FIELD_CLS} mt-1.5`} placeholder="styling consultation" value={form.service_type} onChange={(e) => upd('service_type', e.target.value)} />
                      <p className="text-[11px] text-gray-400 mt-1">Separate multiple values with commas.</p>
                    </div>
                  </div>
                  <button
                    type="submit"
                    className="w-full py-3 rounded-2xl bg-[#fa3f5e] text-white font-bold text-sm hover:opacity-90 transition-opacity flex items-center justify-center gap-2 disabled:opacity-60"
                  >
                    Continue
                  </button>
                </>
              )}
            </form>
          )}
        </div>
      </div>
    </div>
  );
};

export default InfluencerSwitchModal;
