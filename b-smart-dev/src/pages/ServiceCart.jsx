import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Store, ChevronRight, ArrowRight, Trash2, BadgeCheck, Clock, Video, MapPin, UserRound } from 'lucide-react';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { bookingDate, bookingTime } from '../myStore/data/bookingHelpers';
import influencerServiceService from '../services/influencerServiceService';
import { removeItem, toggleSaved } from '../store/serviceCartSlice';

const METHOD_ICON = { Online: Video, 'At customer location': MapPin, 'At my location': Store };
const badge = 'inline-flex items-center gap-1 rounded-full bg-gray-50 dark:bg-gray-800 px-2 py-1 text-[10px] font-bold uppercase tracking-wide text-gray-500 dark:text-gray-400';

export default function ServiceCart() {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const items = useSelector((state) => state.serviceCart.items);
  const [catalog, setCatalog] = useState({});

  useEffect(() => {
    let alive = true;
    influencerServiceService.list()
      .then((list) => { if (alive) setCatalog(Object.fromEntries(list.map((s) => [s.id, s]))); })
      .catch(() => {});
    return () => { alive = false; };
  }, []);

  const active = items.filter((item) => !item.saved);
  const saved = items.filter((item) => item.saved);
  const total = active.reduce((sum, item) => sum + (Number(item.itemTotal) || 0), 0);

  const renderItem = (item, index, { inSaved = false } = {}) => {
    const service = catalog[item.service_id] || {};
    const MethodIcon = METHOD_ICON[service.method] || MapPin;
    const vendorAvatar = service.seller?.avatar_url || service.seller?.profile_picture;
    const address = item.customer_address;

    return (
      <div key={item.localId} className={`rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm p-4 flex gap-4 ${inSaved ? 'opacity-80' : ''}`}>
        <Link to={`/market/service/${item.service_id}`} className="w-24 h-24 shrink-0 rounded-xl overflow-hidden bg-pink-50 dark:bg-gray-800 flex items-center justify-center">
          {item.serviceImage ? <img src={item.serviceImage} alt={item.serviceName} className="w-full h-full object-cover" /> : <ServiceIcon size={28} className="text-[#fa3f5e] opacity-70" />}
        </Link>
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <div className="flex items-center gap-1.5 mb-1 min-w-0">
                {vendorAvatar
                  ? <img src={vendorAvatar} alt={service.provider} className="w-5 h-5 rounded-full object-cover shrink-0" />
                  : <span className="w-5 h-5 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0"><UserRound size={11} className="text-[#fa3f5e]" /></span>}
                <span className="text-xs font-semibold text-gray-600 dark:text-gray-400 truncate">{service.provider || 'Creator'}</span>
                {service.seller?.is_verified && <BadgeCheck size={13} className="text-[#fa3f5e] shrink-0" />}
              </div>
              <Link to={`/market/service/${item.service_id}`}>
                <h3 className="font-bold text-gray-900 dark:text-white text-sm hover:text-[#fa3f5e] transition-colors">{item.serviceName}</h3>
              </Link>
            </div>
            <p className="font-extrabold text-[#fa3f5e] text-base shrink-0">₹{Number(item.itemTotal || 0).toLocaleString()}</p>
          </div>

          <div className="flex flex-wrap items-center gap-1.5 mt-2">
            {service.category && <span className={badge}>{service.category}</span>}
            {service.method && <span className={badge}><MethodIcon size={11} /> {service.method}</span>}
            {service.duration && <span className={badge}><Clock size={11} /> {service.duration}</span>}
          </div>

          <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">
            📅 {bookingDate(item.booking_date)} · 🕐 {bookingTime(item.time_slot?.start)}–{bookingTime(item.time_slot?.end)}
          </p>

          {item.selected_subservices?.length > 0 && (
            <div className="flex flex-wrap gap-1.5 mt-2">
              {item.selected_subservices.map((sub) => {
                const match = service.subservices?.find((s) => s.name === sub.name);
                return (
                  <span key={sub.name} className="rounded-full bg-pink-50 dark:bg-pink-900/10 px-2 py-0.5 text-[11px] font-semibold text-[#fa3f5e]">
                    {sub.name}{match?.price ? ` · ₹${match.price}` : ''}
                  </span>
                );
              })}
            </div>
          )}

          {address && (
            <div className="mt-2 flex items-start gap-1.5 rounded-lg bg-gray-50 dark:bg-gray-800 px-3 py-2 text-xs text-gray-600 dark:text-gray-300">
              <MapPin size={12} className="mt-0.5 shrink-0" />
              {[address.address_line1, address.city, address.pincode].filter(Boolean).join(', ')}
            </div>
          )}

          {item.notes && <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 italic">"{item.notes}"</p>}

          <div className="flex items-center justify-between mt-3">
            <span className="text-[11px] font-semibold text-gray-400">Session {index + 1} of {inSaved ? saved.length : active.length}</span>
            <div className="flex items-center gap-3 text-xs font-bold">
              <button type="button" onClick={() => dispatch(toggleSaved(item.localId))} className="text-gray-500 hover:text-[#fa3f5e] dark:text-gray-400">
                {inSaved ? 'Move to cart' : 'Save for later'}
              </button>
              <button type="button" onClick={() => dispatch(removeItem(item.localId))} aria-label={`Remove ${item.serviceName}`} className="flex items-center gap-1 text-gray-400 hover:text-red-500">
                <Trash2 size={13} /> Remove
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] mx-auto px-4 pt-6">
      <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 mb-4">
        <Link to="/market" className="inline-flex items-center gap-1.5 hover:text-[#fa3f5e]"><Store size={14} /> Marketplace</Link>
        <ChevronRight size={14} />
        <Link to="/market/services" className="hover:text-[#fa3f5e]">Services</Link>
        <ChevronRight size={14} />
        <span className="font-semibold text-gray-700 dark:text-gray-300">Service Cart</span>
      </div>

      <div className="flex flex-wrap items-center gap-3 mb-1">
        <h1 className="text-2xl sm:text-3xl font-extrabold text-gray-900 dark:text-white">Service Cart</h1>
        {active.length > 0 && <span className="rounded-full bg-[#fa3f5e] px-2.5 py-1 text-[11px] font-bold text-white">{active.length} booked</span>}
      </div>
      <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">Review your scheduled sessions before checkout.</p>

      {items.length === 0 ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <ServiceIcon size={36} className="mx-auto text-[#fa3f5e] mb-4" />
          <p className="text-sm text-gray-500 dark:text-gray-400">Your service cart is empty.</p>
          <Link to="/market/services" className="inline-block mt-5 px-5 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Browse Services</Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_340px] gap-5 items-start">
          <main className="min-w-0 space-y-3">
            {active.map((item, index) => renderItem(item, index))}

            <Link to="/market/services" className="block text-center py-3 rounded-xl border border-dashed border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-500 dark:text-gray-400 hover:border-[#fa3f5e] hover:text-[#fa3f5e] transition-colors">
              + Add another service
            </Link>

            {saved.length > 0 && (
              <div className="pt-4">
                <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Saved for later ({saved.length})</h2>
                <div className="space-y-3">
                  {saved.map((item, index) => renderItem(item, index, { inSaved: true }))}
                </div>
              </div>
            )}
          </main>

          <aside className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm p-5 lg:sticky lg:top-6 space-y-4">
            <h2 className="text-base font-bold text-gray-900 dark:text-white">Booking Summary</h2>
            <p className="text-xs text-gray-400">{active.length} session{active.length === 1 ? '' : 's'}</p>
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-500 dark:text-gray-400">Subtotal</span>
              <span className="font-semibold text-gray-900 dark:text-white">₹{total.toLocaleString()}</span>
            </div>
            <div className="flex items-center justify-between border-t border-gray-100 dark:border-gray-800 pt-3">
              <span className="font-bold text-gray-900 dark:text-white">Total</span>
              <span className="font-extrabold text-xl text-[#fa3f5e]">₹{total.toLocaleString()}</span>
            </div>
            <button
              type="button"
              disabled={!active.length}
              onClick={() => navigate('/market/service-checkout')}
              className="w-full flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-[#9f1239] to-[#fa3f5e] py-3 text-sm font-bold text-white disabled:opacity-40 disabled:cursor-not-allowed hover:opacity-90 transition-opacity"
            >
              Proceed to Checkout <ArrowRight size={15} />
            </button>
            <p className="text-[11px] text-center text-gray-400">🔒 Secure payments via Razorpay — UPI, cards, netbanking &amp; wallets.</p>
          </aside>
        </div>
      )}
    </div>
  );
}
