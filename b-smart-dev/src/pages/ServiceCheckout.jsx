import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Store, ChevronRight, Check, BadgeCheck, MapPin, Loader2, CheckCircle2, UserRound } from 'lucide-react';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { bookingDate, bookingTime } from '../myStore/data/bookingHelpers';
import serviceBookingService from '../services/serviceBookingService';
import PaymentSplitSlider from '../components/PaymentSplitSlider';
import { checkoutActive } from '../store/serviceCartSlice';
import { fetchWallet } from '../store/walletSlice';

const STEPS = ['Service Cart', 'Confirm Details', 'Payment', 'Confirmation'];

const toOrderItem = ({ service_id, booking_date, time_slot, selected_subservices, customer_address, notes }) => ({
  service_id, booking_date, time_slot, selected_subservices, customer_address, notes,
});

export default function ServiceCheckout() {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const items = useSelector((state) => state.serviceCart.items).filter((item) => !item.saved);
  const walletBalance = useSelector((state) => state.wallet.balance) || 0;
  const user = useSelector((state) => state.auth.userObject);
  const [coinsToUse, setCoinsToUse] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [placed, setPlaced] = useState(false);
  const [orderNumber, setOrderNumber] = useState('');

  useEffect(() => { dispatch(fetchWallet()); }, [dispatch]);

  const total = items.reduce((sum, item) => sum + (Number(item.itemTotal) || 0), 0);
  const coins = Math.max(0, Math.min(coinsToUse, walletBalance, total));
  const razorpayAmount = Math.max(0, total - coins);
  const hasAtCustomerItems = items.some((item) => item.customer_address);
  const name = user?.name || user?.full_name || user?.username || '';
  const avatar = user?.avatar_url || user?.profile_picture;

  const placeOrder = async () => {
    if (!items.length) return;
    setSubmitting(true);
    setError('');
    try {
      const result = await serviceBookingService.createOrder({
        items: items.map(toOrderItem),
        coins_to_use: coins,
      });
      const order = result?.order || result?.data?.order || {};
      const orderId = order._id || order.id;
      setOrderNumber(order.order_number || '');

      if (order.payment_status === 'paid') {
        dispatch(fetchWallet());
        dispatch(checkoutActive());
        setPlaced(true);
        return;
      }

      const razorpay = result?.razorpay || result?.data?.razorpay;
      if (!orderId || !razorpay?.order_id || !razorpay?.key_id) throw new Error('Razorpay order details were not returned.');
      const loaded = await serviceBookingService.loadRazorpay();
      if (!loaded) throw new Error('Payment gateway failed to load. Please try again.');
      const rzp = new window.Razorpay({
        key: razorpay.key_id,
        amount: razorpay.amount,
        currency: razorpay.currency || 'INR',
        name: 'BSmart',
        description: `${items.length} service${items.length > 1 ? 's' : ''}`,
        order_id: razorpay.order_id,
        prefill: { name, contact: user?.phone || '', email: user?.email || '' },
        handler: async (paymentResponse) => {
          try {
            await serviceBookingService.verifyOrderPayment(orderId, paymentResponse);
            dispatch(fetchWallet());
            dispatch(checkoutActive());
            setPlaced(true);
          } catch (err) {
            setError(err?.response?.data?.message || 'Payment verification failed. Please contact support.');
          } finally {
            setSubmitting(false);
          }
        },
        modal: { ondismiss: () => setSubmitting(false) },
        theme: { color: '#fa3f5e' },
      });
      rzp.on('payment.failed', (response) => {
        setError(response?.error?.description || 'Payment failed. Please try again.');
        setSubmitting(false);
      });
      rzp.open();
    } catch (err) {
      setError(err?.response?.data?.message || err.message || 'Could not place this order.');
      setSubmitting(false);
    }
  };

  if (placed) {
    return (
      <div className="max-w-[1280px] mx-auto px-4 py-20 text-center">
        <CheckCircle2 size={44} className="mx-auto text-[#fa3f5e] mb-4" />
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Booking Confirmed</h1>
        {orderNumber && <p className="text-xs text-gray-400 mt-1">Order #{orderNumber}</p>}
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-3">Your service bookings have been confirmed. The creator will reach out to confirm details.</p>
        <Link to="/market/my-orders" className="inline-block mt-6 px-5 py-3 rounded-full text-sm font-bold text-white bg-gradient-to-r from-[#9f1239] to-[#fa3f5e]">View My Bookings</Link>
      </div>
    );
  }

  if (!items.length) {
    return (
      <div className="max-w-[1280px] mx-auto px-4 py-20 text-center">
        <ServiceIcon size={36} className="mx-auto text-[#fa3f5e] mb-4" />
        <p className="text-sm text-gray-500 dark:text-gray-400">Your service cart is empty.</p>
        <Link to="/market/services" className="inline-block mt-5 px-5 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Browse Services</Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] mx-auto px-4 pt-6">
      <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 mb-5">
        <Link to="/market" className="inline-flex items-center gap-1.5 hover:text-[#fa3f5e]"><Store size={14} /> Marketplace</Link>
        <ChevronRight size={14} />
        <Link to="/market/service-cart" className="hover:text-[#fa3f5e]">Service Cart</Link>
        <ChevronRight size={14} />
        <span className="font-semibold text-gray-700 dark:text-gray-300">Checkout</span>
      </div>

      {/* Step bar */}
      <div className="flex items-center mb-7 max-w-xl">
        {STEPS.map((label, index) => {
          const complete = index === 0;
          const current = index === 1 || index === 2;
          return (
            <React.Fragment key={label}>
              <div className="flex items-center gap-2 shrink-0">
                <span className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold ${complete ? 'bg-[#fa3f5e] text-white' : current ? 'bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] border-2 border-[#fa3f5e]' : 'bg-gray-100 dark:bg-gray-800 text-gray-400'}`}>
                  {complete ? <Check size={14} /> : index + 1}
                </span>
                <span className={`text-xs font-semibold whitespace-nowrap ${complete || current ? 'text-gray-900 dark:text-white' : 'text-gray-400'}`}>{label}</span>
              </div>
              {index < STEPS.length - 1 && <div className={`h-px flex-1 mx-2 ${index === 0 ? 'bg-[#fa3f5e]' : 'bg-gray-100 dark:bg-gray-800'}`} />}
            </React.Fragment>
          );
        })}
      </div>

      <h1 className="text-2xl font-extrabold text-gray-900 dark:text-white mb-5">Finalize Your Bookings</h1>

      <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_360px] gap-5 items-start">
        <main className="min-w-0 space-y-4">
          <section className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm p-5">
            <h2 className="flex items-center gap-2 font-bold text-sm text-gray-900 dark:text-white mb-4">
              <span className="flex h-5 w-5 items-center justify-center rounded-full bg-[#fa3f5e] text-white text-[11px] font-bold">1</span>
              Confirm Your Details
            </h2>
            <div className="flex items-center gap-3">
              {avatar
                ? <img src={avatar} alt={name} className="w-11 h-11 rounded-full object-cover shrink-0" />
                : <span className="w-11 h-11 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0"><UserRound size={20} className="text-[#fa3f5e]" /></span>}
              <div className="min-w-0">
                <p className="flex items-center gap-1.5 font-semibold text-sm text-gray-900 dark:text-white">
                  {name} {user?.is_verified && <BadgeCheck size={14} className="text-[#fa3f5e]" />}
                </p>
                <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{user?.email}</p>
                {user?.phone && <p className="text-xs text-gray-500 dark:text-gray-400">{user.phone}</p>}
              </div>
              <Link to="/settings/account" className="ml-auto shrink-0 text-xs font-bold text-[#fa3f5e]">Edit</Link>
            </div>
            {hasAtCustomerItems && (
              <div className="mt-4 flex items-start gap-2 rounded-xl bg-gray-50 dark:bg-gray-800 px-3 py-2.5 text-xs text-gray-600 dark:text-gray-300">
                <MapPin size={13} className="mt-0.5 shrink-0" />
                Some of these sessions will be delivered at the address you provided when booking. Manage saved addresses in Settings.
              </div>
            )}
          </section>

          <section className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm p-5">
            <h2 className="flex items-center gap-2 font-bold text-sm text-gray-900 dark:text-white mb-4">
              <span className="flex h-5 w-5 items-center justify-center rounded-full bg-[#fa3f5e] text-white text-[11px] font-bold">2</span>
              Payment
            </h2>
            <p className="text-xs font-bold uppercase tracking-wide text-gray-400 mb-2">How would you like to pay?</p>
            <PaymentSplitSlider totalAmount={total} walletBalance={walletBalance} value={coinsToUse} onChange={setCoinsToUse} />
            <div className="mt-4 flex items-center gap-3 rounded-xl border border-gray-100 dark:border-gray-800 p-3">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[#072654] text-[11px] font-black text-white">RP</span>
              <div className="min-w-0">
                <p className="flex items-center gap-1.5 text-sm font-semibold text-gray-900 dark:text-white">Razorpay Checkout <BadgeCheck size={13} className="text-[#fa3f5e]" /></p>
                <p className="text-xs text-gray-500 dark:text-gray-400">UPI, Cards, NetBanking &amp; Wallets — opens Razorpay's secure checkout.</p>
              </div>
            </div>
          </section>
        </main>

        <aside className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm p-5 lg:sticky lg:top-6 space-y-4">
          <h2 className="text-base font-bold text-gray-900 dark:text-white">Service Booking Review</h2>
          <p className="text-xs text-gray-400">{items.length} service{items.length === 1 ? '' : 's'}</p>

          <div className="space-y-3 max-h-64 overflow-y-auto pr-1">
            {items.map((item) => (
              <div key={item.localId} className="flex items-center gap-3">
                <div className="w-11 h-11 shrink-0 rounded-lg overflow-hidden bg-pink-50 dark:bg-gray-800 flex items-center justify-center">
                  {item.serviceImage ? <img src={item.serviceImage} alt={item.serviceName} className="w-full h-full object-cover" /> : <ServiceIcon size={16} className="text-[#fa3f5e] opacity-70" />}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-xs font-semibold text-gray-900 dark:text-white truncate">{item.serviceName}</p>
                  <p className="text-[11px] text-gray-400">{bookingDate(item.booking_date)} · {bookingTime(item.time_slot?.start)}</p>
                </div>
                <p className="text-xs font-bold text-gray-900 dark:text-white shrink-0">₹{Number(item.itemTotal || 0).toLocaleString()}</p>
              </div>
            ))}
          </div>

          <div className="space-y-1.5 border-t border-gray-100 dark:border-gray-800 pt-3 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-gray-500 dark:text-gray-400">Subtotal</span>
              <span className="font-semibold text-gray-900 dark:text-white">₹{total.toLocaleString()}</span>
            </div>
            {coins > 0 && (
              <div className="flex items-center justify-between text-emerald-600">
                <span>Wallet / bCoins</span>
                <span>-₹{coins.toLocaleString()}</span>
              </div>
            )}
            <div className="flex items-center justify-between border-t border-gray-100 dark:border-gray-800 pt-2">
              <span className="font-bold text-gray-900 dark:text-white">Total Payable</span>
              <span className="font-extrabold text-xl text-[#fa3f5e]">₹{razorpayAmount > 0 ? razorpayAmount.toLocaleString() : total.toLocaleString()}</span>
            </div>
          </div>

          {error && <p role="alert" className="text-xs text-[#fa3f5e]">{error}</p>}

          <button
            type="button"
            onClick={placeOrder}
            disabled={submitting}
            className="w-full flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-[#9f1239] to-[#fa3f5e] py-3 text-sm font-bold text-white disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-90 transition-opacity"
          >
            {submitting ? <><Loader2 size={16} className="animate-spin" /> Processing...</> : razorpayAmount > 0 ? `Pay ₹${razorpayAmount.toLocaleString()} via Razorpay` : 'Place Order'}
          </button>
          <p className="text-[11px] text-center text-gray-400">🔒 Secure payments via Razorpay.</p>
        </aside>
      </div>
    </div>
  );
}
