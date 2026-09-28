import React, { useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Star, Clock, Home, MapPin, Globe, MessageCircle, BadgeCheck, CheckCircle2, ChevronRight, ShieldCheck, UserRound, CalendarDays } from 'lucide-react';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { inputCls } from '../components/productForm/ProductFormFields';
import { servicePrice } from '../myStore/data/serviceFields';
import { availableTimes } from '../myStore/data/serviceBooking';
import { localDate, bookingTime } from '../myStore/data/bookingHelpers';
import { requestBooking } from '../store/bookingsSlice';

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
  const [address, setAddress] = useState('');
  const [note, setNote] = useState('');
  const [reviewing, setReviewing] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState('');
  const times = availableTimes(service, date);
  const images = service.images || [];
  const atCustomer = service.method === 'At customer location';
  const provider = service.provider || user?.name || user?.full_name || user?.username || 'Service provider';
  const providerAvatar = service.providerAvatar || (!service.provider ? user?.profile_picture || user?.avatar : null);
  const providerVerified = service.providerVerified ?? (!service.provider && !!user?.is_verified);
  const dates = Array.from({ length: 5 }, (_, index) => { const value = new Date(`${date || firstDate}T12:00:00`); value.setDate(value.getDate() + index); return localDate(value); });
  const chosenDay = new Date(`${date}T12:00:00`);
  const selectDate = (value) => { setDate(value); setTime(availableTimes(service, value)[0] || ''); setReviewing(false); setShowAllTimes(false); setError(''); };
  const submit = (event) => {
    event.preventDefault();
    if (!availableTimes(service, date).includes(time)) { setError('Choose an available date and time.'); setReviewing(false); return; }
    if (atCustomer && !address.trim()) { setError('Enter your service address.'); setAddressOpen(true); return; }
    if (!reviewing) { setReviewing(true); return; }
    const buyerId = user?._id || user?.id;
    if (!buyerId) { setError('Please sign in again to request this service.'); return; }
    dispatch(requestBooking({ buyerId: String(buyerId), requestedAt: new Date().toISOString(), serviceId: service.id, service: service.name, customer: user?.name || user?.full_name || user?.username || 'Customer', date, time, amount: Number(service.price), duration: service.duration, address: atCustomer ? address.trim() : service.method === 'Online' ? 'Online' : service.address, note: note.trim() }));
    setSubmitted(true);
  };

  if (submitted) return <div className="max-w-[1280px] ml-auto px-4 py-20 text-center"><CheckCircle2 size={44} className="mx-auto text-[#fa3f5e] mb-4" /><h1 className="text-2xl font-bold text-gray-900 dark:text-white">Booking request created</h1><p className="text-sm text-gray-500 mt-3">{service.name} · {date} · {bookingTime(time)}</p><p className="text-xs text-gray-400 mt-2">Demo request saved for this session. No payment was collected.</p><Link to="/market/my-store/bookings" className={`${primary} inline-block mt-6 px-5 py-3`}>View bookings</Link></div>;

  return <div className="w-full max-w-[1280px] ml-auto px-4 md:px-6 py-6 bg-gray-50 dark:bg-black min-h-screen text-gray-900 dark:text-white">
    <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-2 text-xs text-gray-500 mb-5"><Link to={fromServices ? '/market/my-store' : '/market'}>{fromServices ? 'My Store' : 'Marketplace'}</Link><ChevronRight size={12} aria-hidden="true" /><Link to={fromServices ? '/market/my-store/services' : '/market/my-store/profile?tab=Services'}>{fromServices ? 'My Services' : 'Store profile'}</Link><ChevronRight size={12} aria-hidden="true" /><span aria-current="page" className="text-[#fa3f5e]">{service.name}</span></nav>
    <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_340px] gap-5 items-start">
      <main className="min-w-0 space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-[minmax(0,0.95fr)_minmax(0,1fr)] gap-5">
          <div className="relative h-[260px] sm:h-[300px] overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
            {images[photo] && !failedImages[photo] ? <img src={images[photo]} alt={`${service.name}, photo ${photo + 1}`} onError={() => setFailedImages({ ...failedImages, [photo]: true })} className="w-full h-full object-cover" /> : <ServiceIcon size={72} className="text-[#fa3f5e]/60" />}
            {images.length > 1 && <div className="absolute bottom-3 inset-x-0 flex justify-center gap-2">{images.map((image, index) => <button type="button" key={`${image}-${index}`} aria-label={`Show photo ${index + 1}`} aria-pressed={photo === index} onClick={() => setPhoto(index)} className={`w-2.5 h-2.5 rounded-full ring-1 ring-black/10 ${photo === index ? 'bg-[#fa3f5e]' : 'bg-white'}`} />)}</div>}
          </div>
          <div className="min-w-0 py-1"><p className="text-xs font-semibold text-insta-purple">{service.category}</p><h1 className="text-2xl font-bold mt-2 break-words">{service.name}</h1><div className="flex flex-wrap items-center gap-3 text-xs mt-4"><span className="flex items-center gap-1"><Star size={16} className="text-[#fa3f5e] fill-current" />{service.rating > 0 ? `${service.rating} · ${service.reviews || 0} reviews` : 'New service'}</span><span className="font-semibold text-[#fa3f5e]">{servicePrice(service)}</span><span className="flex items-center gap-1 text-gray-500"><Clock size={14} />{service.duration}</span></div><p className="text-sm leading-6 text-gray-500 dark:text-gray-400 mt-4">{service.description}</p>
            <div className="grid grid-cols-2 gap-3 border-t border-gray-200 dark:border-gray-800 mt-4 pt-4"><section><h2 className="text-xs font-semibold mb-3">What’s included</h2><ul className="space-y-2">{service.highlights?.filter(Boolean).length ? service.highlights.filter(Boolean).map((highlight) => <li key={highlight} className="flex gap-2 text-xs leading-5 text-gray-500 dark:text-gray-400"><CheckCircle2 size={14} className="text-[#fa3f5e] shrink-0 mt-0.5" />{highlight}</li>) : <li className="text-xs leading-5 text-gray-500">Contact the provider for service inclusions.</li>}</ul></section><section className="border-l border-gray-200 dark:border-gray-800 pl-3"><h2 className="text-xs font-semibold mb-4">Service method</h2><div className="flex flex-wrap items-center gap-2 text-xs text-gray-500"><span className="rounded-full p-2 bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">{service.method === 'Online' ? <Globe size={23} /> : <Home size={23} />}</span>{service.method === 'Online' ? 'Online' : atCustomer ? 'At your location' : 'At provider location'}</div></section></div>
          </div>
        </div>
        <section className={`${panel} px-3 py-2.5 flex items-center gap-3`}>
          <span className="relative shrink-0"><span className="w-11 h-11 rounded-full overflow-hidden bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">{providerAvatar ? <img src={providerAvatar} alt={provider} className="w-full h-full object-cover" /> : <UserRound size={24} className="text-[#fa3f5e]" />}</span>{providerVerified && <BadgeCheck size={17} className="absolute -bottom-0.5 -right-0.5 text-[#fa3f5e] fill-white dark:fill-gray-900" />}</span>
          <div className="flex-1 min-w-0"><h2 className="text-xs font-semibold">Provided by {provider}</h2>{providerVerified && <p className="flex items-center gap-1 text-[11px] text-insta-purple mt-1"><BadgeCheck size={13} />Verified provider</p>}</div>
          <Link to="/messages" className="flex items-center gap-2 rounded-lg border border-gray-200 dark:border-gray-700 px-3 py-2 text-xs shadow-sm"><MessageCircle size={14} />Message</Link>
        </section>
        <section className={`${panel} p-3 grid gap-4 ${service.recentReview?.image ? 'grid-cols-[minmax(0,1fr)_110px] sm:grid-cols-[minmax(0,1fr)_140px]' : 'grid-cols-1'}`}>
          <div className="min-w-0"><h2 className="text-xs font-semibold mb-2">Recent review</h2>{service.recentReview ? <><p className="text-xs flex flex-wrap items-center gap-2"><Star size={14} className="text-[#fa3f5e] fill-current" /><strong>{service.rating || service.recentReview.rating}</strong>{service.reviews > 0 && <span className="text-gray-500">{service.reviews} reviews</span>}</p><p className="text-xs leading-5 text-gray-500 dark:text-gray-400 mt-2 max-w-sm">{service.recentReview.text}</p><p className="text-[11px] text-gray-400 mt-2">— {service.recentReview.author}</p></> : <p className="text-xs text-gray-500">No reviews yet.</p>}</div>
          {service.recentReview?.image && <img src={service.recentReview.image} alt="Customer review" className="w-full h-28 rounded-lg object-cover" />}
        </section>
        <details className={`${panel} p-4 group`}><summary className="flex items-center gap-3 cursor-pointer list-none text-xs"><ShieldCheck size={20} className="text-gray-500" /><span className="flex-1">Cancellation policy</span><ChevronRight size={17} className="group-open:rotate-90" /></summary><p className="text-xs leading-6 text-gray-500 mt-3">{service.cancellationPolicy || 'Contact the provider to confirm cancellation terms before booking.'}</p></details>
      </main>
      <aside className={`${panel} p-4 lg:sticky lg:top-6 min-w-0`}>
        <form onSubmit={submit} className="space-y-4"><h2 className="text-sm font-semibold">{reviewing ? 'Review your booking' : 'Select availability'}</h2>
          {reviewing ? <div className="space-y-3 text-sm text-gray-500"><p className="font-semibold text-gray-900 dark:text-white">{service.name}</p><p>{chosenDay.toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' })} · {bookingTime(time)}</p><p>{service.duration}</p><p className="break-words">{atCustomer ? address : service.method === 'Online' ? 'Online' : service.address}</p><p className="font-semibold text-[#fa3f5e]">{servicePrice(service)}</p><button type="button" onClick={() => setReviewing(false)} className="text-xs text-[#fa3f5e]">Edit booking</button></div> : <>
            <div className="flex items-center gap-2"><div className="grid grid-cols-5 gap-1 flex-1 min-w-0">{dates.map((value) => { const day = new Date(`${value}T12:00:00`); return <button type="button" key={value} onClick={() => selectDate(value)} aria-pressed={date === value} className={`rounded-lg border py-2 text-center ${date === value ? 'border-[#fa3f5e] text-[#fa3f5e] bg-pink-50/30 dark:bg-pink-900/10' : 'border-gray-100 dark:border-gray-800 text-gray-500'}`}><span className="block text-[10px]">{day.toLocaleDateString('en-US', { weekday: 'short' })}</span><strong className="block text-sm mt-1">{day.getDate()}</strong><span className="block text-[10px] mt-1">{day.toLocaleDateString('en-US', { month: 'short' })}</span></button>; })}</div><button type="button" aria-label="Choose another date" aria-expanded={calendarOpen} onClick={() => setCalendarOpen(!calendarOpen)} className="rounded-lg border border-gray-100 dark:border-gray-800 p-2 text-gray-500"><CalendarDays size={18} /></button></div>
            {calendarOpen && <label className="block text-xs text-gray-500">Choose another date<input type="date" required min={localDate()} value={date} onChange={(event) => selectDate(event.target.value)} className={`${inputCls} mt-1`} /></label>}
            <h3 className="text-xs font-semibold">{Number.isNaN(chosenDay.getTime()) ? 'Choose a date' : chosenDay.toLocaleDateString('en-US', { month: 'long', day: 'numeric' })}</h3>
            {['Morning', 'Afternoon'].map((period) => { const periodTimes = times.filter((slot) => period === 'Morning' ? slot < '12:00' : slot >= '12:00'); return periodTimes.length > 0 && <fieldset key={period}><legend className="text-xs text-insta-purple mb-2">{period}</legend><div className="grid grid-cols-3 gap-2">{(showAllTimes ? periodTimes : periodTimes.slice(0, 3)).map((slot) => <button type="button" key={slot} aria-pressed={time === slot} onClick={() => { setTime(slot); setError(''); }} className={`rounded-lg border py-2 text-[11px] ${time === slot ? 'bg-[#fa3f5e] border-[#fa3f5e] text-white' : 'border-gray-100 dark:border-gray-800 text-gray-500'}`}>{bookingTime(slot)}</button>)}</div></fieldset>; })}
            {(times.filter((slot) => slot < '12:00').length > 3 || times.filter((slot) => slot >= '12:00').length > 3) && <button type="button" onClick={() => setShowAllTimes(!showAllTimes)} className="text-[11px] text-[#fa3f5e]">{showAllTimes ? 'Show fewer times' : 'More available times'}</button>}{!times.length && <p className="text-xs text-gray-500">No available times on this date. Choose another day.</p>}
            <div className="flex items-center gap-2 rounded-lg border border-gray-100 dark:border-gray-800 p-3 text-xs"><Clock size={16} className="text-gray-500" />{service.duration}</div>
            {atCustomer ? <div><button type="button" onClick={() => setAddressOpen(!addressOpen)} aria-expanded={addressOpen} className="w-full flex items-center gap-2 p-3 rounded-lg border border-gray-100 dark:border-gray-800 text-left"><MapPin size={17} className="text-gray-500 shrink-0" /><span className="flex-1 min-w-0 text-[11px] text-gray-500">Service address<span className="block truncate text-xs text-gray-900 dark:text-white mt-0.5">{address || 'Add your address'}</span></span><ChevronRight size={16} /></button>{addressOpen && <label className="block text-xs text-gray-500"><span className="flex gap-2 items-center mb-2"><MapPin size={16} />Service address</span><textarea required value={address} onChange={(event) => setAddress(event.target.value)} placeholder="Enter your full service address" className={inputCls} /></label>}</div> : <p className="text-xs flex gap-2 text-gray-500"><MapPin size={16} />{service.method === 'Online' ? 'Joining details will be arranged with the provider.' : service.address || 'Contact the provider for the location.'}</p>}
            <details><summary className="text-[11px] text-gray-500 cursor-pointer">Add a note (optional)</summary><label className="block text-xs text-gray-500 mt-2">Note for the provider<textarea value={note} onChange={(event) => setNote(event.target.value)} className={`${inputCls} mt-1`} rows={2} /></label></details>
          </>}
          {error && <p role="alert" className="text-xs text-[#fa3f5e]">{error}</p>}
          <button disabled={!time} className={`${primary} w-full py-3`}>{reviewing ? 'Request booking' : 'Continue'}</button>
        </form>
      </aside>
    </div>
  </div>;
}

export default function ServiceDetail() {
  const { serviceId } = useParams();
  const service = useSelector((state) => state.services.items).find((item) => String(item.id) === serviceId && item.status === 'Published' && item.visible);
  if (!service) return <div className="py-20 px-4 text-center"><h1 className="text-xl font-bold text-gray-900 dark:text-white">Service unavailable</h1><Link to="/market/my-store/profile?tab=Services" className="text-[#fa3f5e] inline-block mt-4">Browse services</Link></div>;
  return <BookingPage key={service.id} service={service} />;
}
