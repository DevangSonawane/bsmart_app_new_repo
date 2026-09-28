import React, { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { X, CalendarDays, MapPin, Map, ShieldCheck, MessageCircle, Info } from 'lucide-react';
import { inputCls, labelCls } from '../../components/productForm/ProductFormFields';
import { acceptBooking, declineBooking, proposeBookingTime, completeBooking } from '../../store/bookingsSlice';
import { bookingDate, bookingTime, bookingStatus, localDate, validProposal } from '../data/bookingHelpers';
import { money } from '../data/orderFilters';
import { CustomerAvatar, BookingBadge } from './BookingUI';

export default function BookingDetails({ booking, closeTo }) {
  const dispatch = useDispatch();
  const headingRef = useRef(null);
  const [showProposal, setShowProposal] = useState(false);
  const [date, setDate] = useState(booking?.proposedDate || '');
  const [time, setTime] = useState(booking?.proposedTime || '');
  const [error, setError] = useState('');
  useEffect(() => { headingRef.current?.focus({ preventScroll: true }); }, []);
  if (!booking) return <aside className="rounded-2xl border border-gray-200 dark:border-gray-800 p-5 bg-white dark:bg-gray-900"><h2 ref={headingRef} tabIndex={-1} className="font-bold text-gray-900 dark:text-white">Booking not found</h2><Link to={closeTo} className="text-sm text-[#fa3f5e] inline-block mt-3">Back to bookings</Link></aside>;
  const actionable = ['New', 'Proposed'].includes(booking.status);
  const earnings = Math.round(booking.amount * 0.9 * 100) / 100;
  const submitProposal = (event) => {
    event.preventDefault();
    if (!validProposal(date, time)) { setError('Choose a date and time in the future.'); return; }
    dispatch(proposeBookingTime({ id: booking.id, date, time }));
    setShowProposal(false);
    setError('');
  };
  return (
    <aside aria-label="Booking details" className="min-w-0 rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm p-5">
      <div className="flex items-center justify-between gap-3 mb-5"><h2 ref={headingRef} tabIndex={-1} className="text-base font-bold text-gray-900 dark:text-white outline-none">{actionable ? 'Booking request' : 'Booking details'}</h2><Link to={closeTo} aria-label="Close booking details" className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800"><X size={17} /></Link></div>
      <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">Requested by</p>
      <div className="flex items-start gap-3 mb-5">
        <CustomerAvatar name={booking.customer} large />
        <div><h3 className="text-sm font-bold text-gray-900 dark:text-white">{booking.customer}</h3>{booking.verified && <p className="flex items-center gap-1 text-[11px] text-[#fa3f5e] mt-1.5"><ShieldCheck size={12} />Verified customer</p>}<Link to="/messages" aria-label="Open messages" className="mt-3 inline-flex items-center gap-1.5 border border-gray-200 dark:border-gray-700 rounded-lg px-3 py-1.5 text-xs text-gray-600 dark:text-gray-300 hover:border-[#fa3f5e]"><MessageCircle size={13} />Message</Link></div>
      </div>
      <div className="space-y-3">
        <div className="rounded-xl border border-gray-100 dark:border-gray-800 p-3.5 space-y-3 text-xs text-gray-600 dark:text-gray-300">
          <p className="font-semibold text-gray-800 dark:text-gray-200">{booking.service}</p>
          <p className="flex items-center gap-2"><CalendarDays size={15} className="text-gray-400" />{bookingDate(booking.date)} · {booking.time}</p>
          <p className="flex items-start gap-2"><MapPin size={15} className="text-gray-400 flex-shrink-0" />{booking.address}</p>
          <a href={`https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(booking.address)}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 font-medium text-[#fa3f5e]"><Map size={15} />Open directions</a>
        </div>
        <div className="rounded-xl border border-gray-100 dark:border-gray-800 p-3.5"><h3 className="text-xs font-semibold text-gray-800 dark:text-gray-200 mb-1.5">Customer note</h3><p className="text-xs leading-5 text-gray-500 dark:text-gray-400">{booking.note || 'No note provided.'}</p></div>
        <div className="flex items-center gap-2 rounded-xl bg-pink-50/70 dark:bg-pink-900/10 p-3.5 text-xs text-[#fa3f5e]"><ShieldCheck size={17} />{booking.paymentSecured ? 'Payment secured' : 'Payment pending'}</div>
        <div className="rounded-xl border border-gray-100 dark:border-gray-800 p-3.5"><div className="flex items-center justify-between gap-3 text-xs font-semibold text-gray-700 dark:text-gray-200">Your earnings<span title="After a 10% demo service fee" aria-label="After a 10% demo service fee"><Info size={14} className="text-gray-400" /></span></div><p className="text-xl font-bold text-[#fa3f5e] mt-1">{money(booking.status === 'Declined' ? 0 : earnings)}</p><p className="text-[10px] text-gray-400 mt-1">After 10% service fee</p></div>
        {booking.status !== 'New' && <div role="status" className="rounded-xl bg-gray-50 dark:bg-gray-800/60 p-3"><BookingBadge status={booking.status} />{booking.status === 'Proposed' && <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">{bookingDate(booking.proposedDate)} · {bookingTime(booking.proposedTime)} — awaiting customer confirmation</p>}</div>}
      </div>
      {actionable && <div className="space-y-2 mt-5">
        {booking.status === 'New' && <button type="button" onClick={() => dispatch(acceptBooking(booking.id))} className="w-full py-2.5 rounded-lg text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Accept</button>}
        <button type="button" aria-expanded={showProposal} onClick={() => setShowProposal(!showProposal)} className="w-full py-2.5 rounded-lg text-sm font-semibold border border-[#fa3f5e]/50 text-[#fa3f5e] hover:bg-pink-50 dark:hover:bg-pink-900/10">{booking.status === 'Proposed' ? 'Update proposed time' : 'Propose new time'}</button>
        {showProposal && <form onSubmit={submitProposal} className="rounded-xl border border-gray-200 dark:border-gray-800 p-3 space-y-3"><div><label htmlFor="proposed-date" className={labelCls}>Date</label><input id="proposed-date" type="date" required min={localDate()} value={date} onChange={(event) => setDate(event.target.value)} className={inputCls} /></div><div><label htmlFor="proposed-time" className={labelCls}>Time</label><input id="proposed-time" type="time" required value={time} onChange={(event) => setTime(event.target.value)} className={inputCls} /></div>{error && <p role="alert" className="text-xs text-red-500">{error}</p>}<button type="submit" className="w-full rounded-lg bg-[#fa3f5e] text-white text-xs font-semibold py-2.5">Save proposed time</button></form>}
        <button type="button" onClick={() => { if (window.confirm(`Decline the booking from ${booking.customer}?`)) dispatch(declineBooking(booking.id)); }} className="w-full py-2.5 rounded-lg text-sm font-semibold border border-red-300 dark:border-red-900 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/10">Decline</button>
      </div>}
      {booking.status === 'Confirmed' && <button type="button" onClick={() => dispatch(completeBooking(booking.id))} className="w-full mt-5 py-2.5 rounded-lg text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Mark as completed</button>}
      <p className="text-[10px] text-gray-400 mt-4">Booking #{booking.id} · {bookingStatus(booking.status)}</p>
    </aside>
  );
}
