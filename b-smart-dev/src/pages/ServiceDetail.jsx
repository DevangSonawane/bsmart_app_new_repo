import React, { useEffect, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  BadgeCheck, CalendarDays, CheckCircle2, ChevronRight, Clock, Globe, Home,
  Loader2, MapPin, MessageCircle, ShieldCheck, Star, UserRound,
} from 'lucide-react';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { inputCls } from '../components/productForm/ProductFormFields';
import { servicePrice } from '../myStore/data/serviceFields';
import { availableTimes, durationMinutes } from '../myStore/data/serviceBooking';
import { bookingTime, localDate } from '../myStore/data/bookingHelpers';
import influencerServiceService from '../services/influencerServiceService';
import serviceBookingService from '../services/serviceBookingService';
import addressService from '../services/addressService';
import { fetchWallet } from '../store/walletSlice';

const panel = 'rounded-xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm';
const primary = 'rounded-lg bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white text-sm font-semibold disabled:opacity-40 disabled:cursor-not-allowed';

function BookingPage({ service }) {
  const [params] = useSearchParams();
  const fromServices = params.get('from') === 'services';
  const user = useSelector((state) => state.auth.userObject);
  const dispatch = useDispatch();
  const [photo, setPhoto] = useState(0);
  const [failedImages, setFailedImages] = useState({});
  const [firstDate] = useState(() => {
    for (let offset = 0; offset < 14; offset += 1) {
      const day = new Date();
      day.setDate(day.getDate() + offset);
      const value = localDate(day);
      if (availableTimes(service, value).length) return value;
    }
    return localDate();
  });
  const [date, setDate] = useState(firstDate);
  const [time, setTime] = useState(() => availableTimes(service, firstDate)[0] || '');
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [addressOpen, setAddressOpen] = useState(false);
  const [showAllTimes, setShowAllTimes] = useState(false);
  const [address, setAddress] = useState({ address_line1: '', city: '', pincode: '' });
  const [savedAddresses, setSavedAddresses] = useState([]);
  const [selectedSavedAddress, setSelectedSavedAddress] = useState('');
  const [addressesLoading, setAddressesLoading] = useState(false);
  const [note, setNote] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('wallet');
  const [selectedSubservices, setSelectedSubservices] = useState([]);
  const [reviewing, setReviewing] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [bookingMessage, setBookingMessage] = useState('');
  const [error, setError] = useState('');

  const times = availableTimes(service, date);
  const images = service.images || [];
  const atCustomer = service.method === 'At customer location';
  const canUseStoreLinks = fromServices && user?.role === 'influencer';
  const provider = service.provider || user?.name || user?.full_name || user?.username || 'Service provider';
  const providerAvatar = service.providerAvatar || (!service.provider ? user?.profile_picture || user?.avatar : null);
  const providerVerified = service.providerVerified ?? (!service.provider && !!user?.is_verified);
  const dates = Array.from({ length: 5 }, (_, index) => { const value = new Date(`${date || firstDate}T12:00:00`); value.setDate(value.getDate() + index); return localDate(value); });
  const chosenDay = new Date(`${date}T12:00:00`);
  const addressText = [address.address_line1, address.city, address.pincode].filter(Boolean).join(', ');

  useEffect(() => {
    if (!atCustomer) return;
    let active = true;
    setAddressesLoading(true);
    addressService.list()
      .then((list) => {
        if (!active) return;
        setSavedAddresses(list);
        const first = list[0];
        if (first) {
          setSelectedSavedAddress(first.id);
          setAddress({
            name: first.name || '',
            phone: first.phone || '',
            address_line1: first.address_line1 || '',
            city: first.city || '',
            state: first.state || '',
            pincode: first.pincode || '',
          });
        }
      })
      .catch(() => {
        if (active) setSavedAddresses([]);
      })
      .finally(() => {
        if (active) setAddressesLoading(false);
      });
    return () => { active = false; };
  }, [atCustomer]);

  const selectDate = (value) => {
    setDate(value);
    setTime(availableTimes(service, value)[0] || '');
    setReviewing(false);
    setShowAllTimes(false);
    setError('');
  };
  const updateAddress = (key, value) => setAddress((current) => ({ ...current, [key]: value }));
  const chooseSavedAddress = (id) => {
    setSelectedSavedAddress(id);
    const saved = savedAddresses.find((entry) => entry.id === id);
    if (!saved) return;
    setAddress({
      name: saved.name || '',
      phone: saved.phone || '',
      address_line1: saved.address_line1 || '',
      city: saved.city || '',
      state: saved.state || '',
      pincode: saved.pincode || '',
    });
  };
  const slotEnd = (start) => {
    const [hours, minutes] = start.split(':').map(Number);
    const total = hours * 60 + minutes + durationMinutes(service.duration);
    return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
  };
  const toggleSubservice = (name) => {
    setSelectedSubservices((current) => current.includes(name) ? current.filter((item) => item !== name) : [...current, name]);
  };

  const submit = async (event) => {
    event.preventDefault();
    if (!availableTimes(service, date).includes(time)) { setError('Choose an available date and time.'); setReviewing(false); return; }
    if (atCustomer && [address.address_line1, address.city, address.pincode].some((value) => !String(value || '').trim())) { setError('Enter your complete service address.'); setAddressOpen(true); return; }
    if (!reviewing) { setReviewing(true); return; }
    const buyerId = user?._id || user?.id;
    if (!buyerId) { setError('Please sign in again to request this service.'); return; }

    setSubmitting(true);
    setError('');
    try {
      const result = await serviceBookingService.create({
        service_id: service.id,
        booking_date: date,
        time_slot: { start: time, end: slotEnd(time) },
        selected_subservices: selectedSubservices.map((name) => ({ name })),
        payment_method: paymentMethod,
        ...(atCustomer ? { customer_address: address } : {}),
        ...(note.trim() ? { note: note.trim() } : {}),
      });
      const booking = result?.booking || result?.service_booking || result?.data?.booking || result?.data?.service_booking || result?.data || {};
      const bookingId = booking._id || booking.id || result?.id || result?._id;

      if (paymentMethod === 'wallet') {
        dispatch(fetchWallet());
        setBookingMessage('Your wallet payment is confirmed and the booking is created.');
        setSubmitted(true);
        return;
      }

      const razorpay = result?.razorpay || result?.data?.razorpay;
      if (!bookingId || !razorpay?.order_id || !razorpay?.key_id) throw new Error('Razorpay booking details were not returned.');
      const loaded = await serviceBookingService.loadRazorpay();
      if (!loaded) throw new Error('Payment gateway failed to load. Please try again.');
      const rzp = new window.Razorpay({
        key: razorpay.key_id,
        amount: razorpay.amount,
        currency: razorpay.currency || 'INR',
        name: 'BSmart',
        description: service.name,
        order_id: razorpay.order_id,
        prefill: { name: user?.name || user?.full_name || '', contact: user?.phone || '', email: user?.email || '' },
        handler: async (paymentResponse) => {
          try {
            await serviceBookingService.verifyPayment(bookingId, paymentResponse);
            setBookingMessage('Payment verified. Your booking is confirmed.');
            setSubmitted(true);
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
      setError(err?.response?.data?.message || err.message || 'Could not create this booking.');
      setSubmitting(false);
    }
  };

  if (submitted) {
    return (
      <div className="max-w-[1280px] ml-auto px-4 py-20 text-center">
        <CheckCircle2 size={44} className="mx-auto text-[#fa3f5e] mb-4" />
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Booking created</h1>
        <p className="text-sm text-gray-500 mt-3">{service.name} - {date} - {bookingTime(time)}</p>
        <p className="text-xs text-gray-400 mt-2">{bookingMessage}</p>
        <Link to="/market/my-orders" className={`${primary} inline-block mt-6 px-5 py-3`}>View bookings</Link>
      </div>
    );
  }

  return <div className="w-full max-w-[1280px] ml-auto px-4 md:px-6 py-6 bg-gray-50 dark:bg-black min-h-screen text-gray-900 dark:text-white">
    <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 mb-5"><Link to={canUseStoreLinks ? '/market/my-store' : '/market'} className="hover:text-[#fa3f5e]">{canUseStoreLinks ? 'My Store' : 'Marketplace'}</Link><ChevronRight size={14} aria-hidden="true" /><Link to={canUseStoreLinks ? '/market/my-store/services' : '/market'} className="hover:text-[#fa3f5e]">{canUseStoreLinks ? 'My Services' : 'Services'}</Link><ChevronRight size={14} aria-hidden="true" /><span aria-current="page" className="text-[#fa3f5e]">{service.name}</span></nav>
    <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_340px] gap-5 items-start">
      <main className="min-w-0 space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-[minmax(0,0.95fr)_minmax(0,1fr)] gap-5">
          <div className="relative h-[260px] sm:h-[300px] overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
            {images[photo] && !failedImages[photo] ? <img src={images[photo]} alt={`${service.name}, photo ${photo + 1}`} onError={() => setFailedImages({ ...failedImages, [photo]: true })} className="w-full h-full object-cover" /> : <ServiceIcon size={72} className="text-[#fa3f5e]/60" />}
            {images.length > 1 && <div className="absolute bottom-3 inset-x-0 flex justify-center gap-2">{images.map((image, index) => <button type="button" key={`${image}-${index}`} aria-label={`Show photo ${index + 1}`} aria-pressed={photo === index} onClick={() => setPhoto(index)} className={`w-2.5 h-2.5 rounded-full ring-1 ring-black/10 ${photo === index ? 'bg-[#fa3f5e]' : 'bg-white'}`} />)}</div>}
          </div>
          <div className="min-w-0 py-1"><p className="text-sm font-semibold text-insta-purple">{service.category}</p><h1 className="text-2xl font-bold mt-2 break-words">{service.name}</h1><div className="flex flex-wrap items-center gap-3 text-sm mt-4"><span className="flex items-center gap-1"><Star size={16} className="text-[#fa3f5e] fill-current" />{service.rating > 0 ? `${service.rating} - ${service.reviews || 0} reviews` : 'New service'}</span><span className="font-semibold text-[#fa3f5e]">{servicePrice(service)}</span><span className="flex items-center gap-1 text-gray-500"><Clock size={14} />{service.duration}</span></div><p className="text-sm leading-6 text-gray-500 dark:text-gray-400 mt-4">{service.description}</p>
            <div className="grid grid-cols-2 gap-3 border-t border-gray-200 dark:border-gray-800 mt-4 pt-4"><section><h2 className="text-base font-bold mb-3 text-gray-900 dark:text-white">What's included</h2><ul className="space-y-2">{service.highlights?.filter(Boolean).length ? service.highlights.filter(Boolean).map((highlight) => <li key={highlight} className="flex gap-2 text-sm leading-6 text-gray-500 dark:text-gray-400"><CheckCircle2 size={15} className="text-[#fa3f5e] shrink-0 mt-1" />{highlight}</li>) : <li className="text-sm leading-6 text-gray-500">Contact the provider for service inclusions.</li>}</ul></section><section className="border-l border-gray-200 dark:border-gray-800 pl-3"><h2 className="text-base font-bold mb-4 text-gray-900 dark:text-white">Service method</h2><div className="flex flex-wrap items-center gap-2 text-sm text-gray-500"><span className="rounded-full p-2 bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">{service.method === 'Online' ? <Globe size={23} /> : <Home size={23} />}</span>{service.method === 'Online' ? 'Online' : atCustomer ? 'At your location' : 'At provider location'}</div></section></div>
          </div>
        </div>
        <section className={`${panel} px-3 py-2.5 flex items-center gap-3`}>
          <span className="relative shrink-0"><span className="w-11 h-11 rounded-full overflow-hidden bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">{providerAvatar ? <img src={providerAvatar} alt={provider} className="w-full h-full object-cover" /> : <UserRound size={24} className="text-[#fa3f5e]" />}</span>{providerVerified && <BadgeCheck size={17} className="absolute -bottom-0.5 -right-0.5 text-[#fa3f5e] fill-white dark:fill-gray-900" />}</span>
          <div className="flex-1 min-w-0"><h2 className="text-sm font-bold text-gray-900 dark:text-white">Provided by {provider}</h2>{providerVerified && <p className="flex items-center gap-1 text-xs text-insta-purple mt-1"><BadgeCheck size={13} />Verified provider</p>}</div>
          <Link to="/messages" className="flex items-center gap-2 rounded-lg border border-gray-200 dark:border-gray-700 px-3 py-2 text-sm font-semibold shadow-sm"><MessageCircle size={14} />Message</Link>
        </section>
        <details className={`${panel} p-4 group`}><summary className="flex items-center gap-3 cursor-pointer list-none text-sm font-semibold text-gray-900 dark:text-white"><ShieldCheck size={20} className="text-gray-500" /><span className="flex-1">Cancellation policy</span><ChevronRight size={17} className="group-open:rotate-90" /></summary><p className="text-sm leading-6 text-gray-500 mt-3">{service.cancellationPolicy || 'Contact the provider to confirm cancellation terms before booking.'}</p></details>
      </main>
      <aside className={`${panel} p-4 lg:sticky lg:top-6 min-w-0`}>
        {canUseStoreLinks ? (
          <div className="space-y-4">
            <h2 className="text-base font-bold text-gray-900 dark:text-white">Store service</h2>
            <p className="text-sm leading-6 text-gray-500 dark:text-gray-400">You are viewing this service from My Store.</p>
            <div className="rounded-lg border border-gray-100 p-3 text-sm text-gray-500 dark:border-gray-800 dark:text-gray-400">
              <p className="font-bold text-gray-900 dark:text-white">{service.status || 'Published'}</p>
              <p className="mt-1">{service.visible ? 'Visible to customers' : 'Hidden from customers'}</p>
            </div>
            <Link to="/market/my-store/services" className="block rounded-xl border border-gray-200 py-3 text-center text-sm font-bold text-gray-800 dark:border-gray-700 dark:text-gray-200">
              Back to My Services
            </Link>
            <Link to={`/market/edit-service/${service.id}`} className={`${primary} block py-3 text-center`}>
              Edit Service
            </Link>
          </div>
        ) : (
        <form onSubmit={submit} className="space-y-4"><h2 className="text-base font-bold text-gray-900 dark:text-white">{reviewing ? 'Review your booking' : 'Select availability'}</h2>
          {reviewing ? <div className="space-y-3 text-sm text-gray-500"><p className="font-semibold text-gray-900 dark:text-white">{service.name}</p><p>{chosenDay.toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' })} - {bookingTime(time)}</p><p>{service.duration}</p><p className="break-words">{atCustomer ? addressText : service.method === 'Online' ? 'Online' : service.address}</p>{selectedSubservices.length > 0 && <p>Selected: {selectedSubservices.join(', ')}</p>}<p className="font-semibold text-[#fa3f5e]">{servicePrice(service)}</p><p className="text-xs">Payment: {paymentMethod === 'wallet' ? 'Wallet' : 'Razorpay'}</p><button type="button" onClick={() => setReviewing(false)} className="text-xs text-[#fa3f5e]">Edit booking</button></div> : <>
            <div className="flex items-center gap-2"><div className="grid grid-cols-5 gap-1 flex-1 min-w-0">{dates.map((value) => { const day = new Date(`${value}T12:00:00`); return <button type="button" key={value} onClick={() => selectDate(value)} aria-pressed={date === value} className={`rounded-lg border py-2 text-center ${date === value ? 'border-[#fa3f5e] text-[#fa3f5e] bg-pink-50/30 dark:bg-pink-900/10' : 'border-gray-100 dark:border-gray-800 text-gray-500'}`}><span className="block text-[10px]">{day.toLocaleDateString('en-US', { weekday: 'short' })}</span><strong className="block text-sm mt-1">{day.getDate()}</strong><span className="block text-[10px] mt-1">{day.toLocaleDateString('en-US', { month: 'short' })}</span></button>; })}</div><button type="button" aria-label="Choose another date" aria-expanded={calendarOpen} onClick={() => setCalendarOpen(!calendarOpen)} className="rounded-lg border border-gray-100 dark:border-gray-800 p-2 text-gray-500"><CalendarDays size={18} /></button></div>
            {calendarOpen && <label className="block text-xs text-gray-500">Choose another date<input type="date" required min={localDate()} value={date} onChange={(event) => selectDate(event.target.value)} className={`${inputCls} mt-1`} /></label>}
            <h3 className="text-sm font-bold text-gray-900 dark:text-white">{Number.isNaN(chosenDay.getTime()) ? 'Choose a date' : chosenDay.toLocaleDateString('en-US', { month: 'long', day: 'numeric' })}</h3>
            {['Morning', 'Afternoon'].map((period) => { const periodTimes = times.filter((slot) => period === 'Morning' ? slot < '12:00' : slot >= '12:00'); return periodTimes.length > 0 && <fieldset key={period}><legend className="text-xs text-insta-purple mb-2">{period}</legend><div className="grid grid-cols-3 gap-2">{(showAllTimes ? periodTimes : periodTimes.slice(0, 3)).map((slot) => <button type="button" key={slot} aria-pressed={time === slot} onClick={() => { setTime(slot); setError(''); }} className={`rounded-lg border py-2 text-[11px] ${time === slot ? 'bg-[#fa3f5e] border-[#fa3f5e] text-white' : 'border-gray-100 dark:border-gray-800 text-gray-500'}`}>{bookingTime(slot)}</button>)}</div></fieldset>; })}
            {(times.filter((slot) => slot < '12:00').length > 3 || times.filter((slot) => slot >= '12:00').length > 3) && <button type="button" onClick={() => setShowAllTimes(!showAllTimes)} className="text-[11px] text-[#fa3f5e]">{showAllTimes ? 'Show fewer times' : 'More available times'}</button>}{!times.length && <p className="text-xs text-gray-500">No available times on this date. Choose another day.</p>}
            <div className="flex items-center gap-2 rounded-lg border border-gray-100 dark:border-gray-800 p-3 text-xs"><Clock size={16} className="text-gray-500" />{service.duration}</div>
            {service.subservices?.length > 0 && <fieldset className="space-y-2"><legend className="text-sm font-bold text-gray-900 dark:text-white">Subservices</legend>{service.subservices.map((item) => <label key={item.name} className="flex items-center gap-2 text-sm text-gray-500"><input type="checkbox" checked={selectedSubservices.includes(item.name)} onChange={() => toggleSubservice(item.name)} className="accent-[#fa3f5e]" />{item.name}</label>)}</fieldset>}
            {atCustomer ? <div><button type="button" onClick={() => setAddressOpen(!addressOpen)} aria-expanded={addressOpen} className="w-full flex items-center gap-2 p-3 rounded-lg border border-gray-100 dark:border-gray-800 text-left"><MapPin size={17} className="text-gray-500 shrink-0" /><span className="flex-1 min-w-0 text-[11px] text-gray-500">Service address<span className="block truncate text-xs text-gray-900 dark:text-white mt-0.5">{addressesLoading ? 'Loading saved addresses...' : addressText || 'Add your address'}</span></span><ChevronRight size={16} /></button>{addressOpen && <div className="space-y-2">{savedAddresses.length > 0 && <label className="block text-xs text-gray-500">Saved address<select value={selectedSavedAddress} onChange={(event) => chooseSavedAddress(event.target.value)} className={`${inputCls} mt-1`}><option value="">Choose saved address</option>{savedAddresses.map((entry) => <option key={entry.id} value={entry.id}>{entry.label} - {entry.city}, {entry.pincode}</option>)}</select></label>}<label className="block text-xs text-gray-500">Address line<input required value={address.address_line1} onChange={(event) => updateAddress('address_line1', event.target.value)} className={`${inputCls} mt-1`} /></label><label className="block text-xs text-gray-500">City<input required value={address.city} onChange={(event) => updateAddress('city', event.target.value)} className={`${inputCls} mt-1`} /></label><label className="block text-xs text-gray-500">Pincode<input required value={address.pincode} onChange={(event) => updateAddress('pincode', event.target.value)} className={`${inputCls} mt-1`} /></label></div>}</div> : <p className="text-xs flex gap-2 text-gray-500"><MapPin size={16} />{service.method === 'Online' ? 'Joining details will be arranged with the provider.' : service.address || 'Contact the provider for the location.'}</p>}
            <fieldset className="space-y-2"><legend className="text-sm font-bold text-gray-900 dark:text-white">Payment method</legend>{[['wallet', 'Wallet'], ['razorpay', 'Razorpay']].map(([value, label]) => <label key={value} className="flex items-center gap-2 text-sm text-gray-500"><input type="radio" name="payment_method" value={value} checked={paymentMethod === value} onChange={() => setPaymentMethod(value)} className="accent-[#fa3f5e]" />{label}</label>)}</fieldset>
            <details><summary className="text-[11px] text-gray-500 cursor-pointer">Add a note (optional)</summary><label className="block text-xs text-gray-500 mt-2">Note for the provider<textarea value={note} onChange={(event) => setNote(event.target.value)} className={`${inputCls} mt-1`} rows={2} /></label></details>
          </>}
          {error && <p role="alert" className="text-xs text-[#fa3f5e]">{error}</p>}
          <button disabled={!time || submitting} className={`${primary} w-full py-3`}>{submitting ? 'Processing...' : reviewing ? 'Book service' : 'Continue'}</button>
        </form>
        )}
      </aside>
    </div>
  </div>;
}

export default function ServiceDetail() {
  const { serviceId } = useParams();
  const fallbackService = useSelector((state) => state.services.items).find((item) => String(item.id) === serviceId && item.status === 'Published' && item.visible);
  const [apiService, setApiService] = useState(null);
  const [loading, setLoading] = useState(true);
  const service = apiService || fallbackService;

  useEffect(() => {
    let alive = true;
    influencerServiceService.get(serviceId)
      .then((item) => { if (alive) setApiService(item); })
      .catch(() => { if (alive) setApiService(null); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [serviceId]);

  if (loading && !service) return (
    <div className="py-20 px-4 text-center">
      <Loader2 size={24} className="animate-spin text-[#fa3f5e] mx-auto mb-3" />
      <p className="text-gray-500 dark:text-gray-400">Loading service...</p>
    </div>
  );
  if (!service) return <div className="py-20 px-4 text-center"><h1 className="text-xl font-bold text-gray-900 dark:text-white">Service unavailable</h1><Link to="/market" className="text-[#fa3f5e] inline-block mt-4">Browse services</Link></div>;
  return <BookingPage key={service.id} service={service} />;
}
