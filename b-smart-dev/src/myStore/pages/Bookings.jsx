import React, { useEffect, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Search, CalendarDays, MapPin, ShieldCheck, X, Loader2, RefreshCw } from 'lucide-react';
import { inputCls } from '../../components/productForm/ProductFormFields';
import BookingDetails from '../components/BookingDetails';
import { CustomerAvatar, BookingBadge } from '../components/BookingUI';
import { BOOKING_TABS, filterBookings, bookingDate, localDate } from '../data/bookingHelpers';
import { money } from '../data/orderFilters';
import serviceBookingService from '../../services/serviceBookingService';
import RowActionsMenu from '../components/RowActionsMenu';

const BASE = '/market/my-store/bookings';

export default function StoreBookings() {
  const fallbackBookings = useSelector((state) => state.bookings.items);
  const [apiBookings, setApiBookings] = useState([]);
  const [apiLoaded, setApiLoaded] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [updatingId, setUpdatingId] = useState('');
  const { bookingId } = useParams();
  const [params, setParams] = useSearchParams();
  const tab = BOOKING_TABS.includes(params.get('tab')) ? params.get('tab') : 'Requests';
  const search = params.get('search') || '';
  const date = params.get('date') || '';
  const setFilter = (key, value) => setParams((current) => { const next = new URLSearchParams(current); if (value) next.set(key, value); else next.delete(key); return next; }, { replace: true });
  const bookings = apiLoaded ? apiBookings : fallbackBookings;
  const filtered = filterBookings(bookings, { tab, search, date });
  const today = bookings.filter((booking) => booking.date === localDate() && ['Confirmed', 'In Progress'].includes(booking.status));
  const suffix = params.size ? `?${params.toString()}` : '';
  const active = bookings.find((booking) => booking.id === bookingId);
  const viewUrl = (id) => `${BASE}/${id}${suffix}`;

  const fetchBookings = async () => {
    setLoading(true);
    setError('');
    try {
      setApiBookings(await serviceBookingService.listSeller());
      setApiLoaded(true);
    } catch (err) {
      setApiLoaded(false);
      setError(err?.response?.data?.message || 'Could not load live service bookings. Showing local bookings.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchBookings(); }, []);

  useEffect(() => {
    if (!bookingId || !apiLoaded) return;
    let alive = true;
    serviceBookingService.get(bookingId)
      .then((fresh) => {
        if (!alive) return;
        setApiBookings((current) => current.some((booking) => booking.id === fresh.id)
          ? current.map((booking) => booking.id === fresh.id ? fresh : booking)
          : [fresh, ...current]);
      })
      .catch((err) => {
        if (alive) setError(err?.response?.data?.message || 'Could not load booking details.');
      });
    return () => { alive = false; };
  }, [bookingId, apiLoaded]);

  const updateBookingStatus = async (id, status) => {
    setUpdatingId(id);
    setError('');
    try {
      const updated = await serviceBookingService.updateStatus(id, status);
      setApiBookings((current) => current.map((booking) => booking.id === id ? updated : booking));
      setApiLoaded(true);
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not update booking status.');
    } finally {
      setUpdatingId('');
    }
  };
  return (
    <div className="max-w-[1280px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className="flex items-start gap-4 lg:gap-6">
        <section aria-label="Bookings" className={`min-w-0 flex-1 ${bookingId ? 'hidden md:block' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-3 mb-5">
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Bookings</h1>
            <button type="button" onClick={fetchBookings} className="inline-flex items-center gap-2 text-xs font-semibold text-[#fa3f5e]"><RefreshCw size={14} />Refresh</button>
          </div>
          {loading && <div className="flex items-center gap-2 text-sm text-gray-500 mb-4"><Loader2 size={16} className="animate-spin" />Loading bookings...</div>}
          {error && <p role="alert" className="mb-4 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">{error}</p>}
          <div className="flex gap-6 border-b border-gray-200 dark:border-gray-800 mb-5">{BOOKING_TABS.map((value) => <button type="button" key={value} aria-pressed={tab === value} onClick={() => setFilter('tab', value)} className={`pb-3 text-sm font-semibold border-b-2 transition-colors ${tab === value ? 'border-[#fa3f5e] text-[#fa3f5e]' : 'border-transparent text-gray-500 dark:text-gray-400'}`}>{value}</button>)}</div>
          <div className="flex flex-wrap gap-3 items-center justify-between mb-5">
            <div className="relative flex-1 sm:max-w-md min-w-[180px]"><Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" /><input aria-label="Search bookings" value={search} onChange={(event) => setFilter('search', event.target.value)} placeholder="Search bookings" className={`${inputCls} pl-9`} /></div>
            <div className="flex items-center gap-2"><label className="flex items-center gap-2 text-gray-500 dark:text-gray-400"><CalendarDays size={16} /><input type="date" aria-label="Filter bookings by date" value={date} onChange={(event) => setFilter('date', event.target.value)} className={`${inputCls} w-40`} /></label>{date && <button type="button" aria-label="Clear booking date" onClick={() => setFilter('date', '')} className="text-gray-400"><X size={15} /></button>}</div>
          </div>
          <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 overflow-x-auto shadow-sm">
            <table className="w-full min-w-[600px] text-xs">
              <thead><tr className="text-left text-gray-500 dark:text-gray-400 border-b border-gray-100 dark:border-gray-800">{['Service', 'Date & time', 'Amount', 'Status', 'Actions'].map((heading) => <th key={heading} className={`px-4 py-3.5 font-medium ${heading === 'Actions' ? 'text-right' : ''}`}>{heading}</th>)}</tr></thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-800">{filtered.map((booking) => <tr key={booking.id} className={booking.id === bookingId ? 'bg-pink-50/60 dark:bg-pink-900/10 ring-1 ring-inset ring-[#fa3f5e]/40' : 'hover:bg-gray-50 dark:hover:bg-gray-800/30'}>
                <td className="px-4 py-4"><div className="flex items-center gap-2.5"><CustomerAvatar name={booking.customer} /><div><Link to={viewUrl(booking.id)} className="font-semibold text-gray-800 dark:text-gray-200 hover:text-[#fa3f5e]">{booking.service}</Link><p className="text-[11px] text-gray-500 dark:text-gray-400 mt-1">{booking.customer}</p></div></div></td>
                <td className="px-4 py-4 text-gray-500 dark:text-gray-400 whitespace-nowrap"><span className="flex items-center gap-1.5"><CalendarDays size={13} />{bookingDate(booking.date)} · {booking.time}</span></td>
                <td className="px-4 py-4 text-[#fa3f5e] font-semibold">{money(booking.amount)}</td>
                <td className="px-4 py-4"><BookingBadge status={booking.status} /></td>
                <td className="px-4 py-4 text-right">
                  <RowActionsMenu ariaLabel={`Actions for booking ${booking.id}`} menuClassName="w-40">
                    {(close) => (
                      <Link role="menuitem" to={viewUrl(booking.id)} onClick={close} className="flex items-center gap-2 px-3.5 py-2 text-xs font-semibold text-gray-600 hover:bg-gray-50 hover:text-[#fa3f5e] dark:text-gray-300 dark:hover:bg-gray-800">
                        View booking
                      </Link>
                    )}
                  </RowActionsMenu>
                </td>
              </tr>)}{!filtered.length && <tr><td colSpan={5} className="text-center py-12 text-gray-400">No bookings match this view.</td></tr>}</tbody>
            </table>
          </div>
          <div className="mt-7"><h2 className="text-sm font-bold text-gray-800 dark:text-gray-200 mb-3">Today’s services</h2><div className="space-y-3">{today.map((booking) => <Link key={booking.id} to={viewUrl(booking.id)} className="flex flex-wrap items-center gap-4 p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-sm hover:border-[#fa3f5e]/40">
            <div className="flex items-center gap-2.5 min-w-[170px]"><CustomerAvatar name={booking.customer} /><div><p className="text-xs font-semibold text-gray-800 dark:text-gray-200">{booking.customer}</p><p className="text-[11px] text-gray-500 dark:text-gray-400 mt-1">{booking.service}</p>{booking.verified && <p className="flex gap-1 items-center text-[10px] text-[#fa3f5e] mt-1"><ShieldCheck size={11} />Verified customer</p>}</div></div>
            <div className="flex-1 text-[11px] text-gray-500 dark:text-gray-400 space-y-2"><p className="flex gap-2 items-center"><CalendarDays size={13} />{bookingDate(booking.date)} · {booking.time}</p><p className="flex gap-2 items-center"><MapPin size={13} className="flex-shrink-0" />{booking.address}</p></div><BookingBadge status={booking.status} />
          </Link>)}{!today.length && <div className="p-6 text-sm text-gray-400 border border-gray-100 dark:border-gray-800 rounded-xl bg-white dark:bg-gray-900">No confirmed services scheduled for today.</div>}</div></div>
        </section>
        {bookingId && (
          <div className="w-full md:w-[300px] lg:w-[340px] shrink-0 md:sticky md:top-6">
            <BookingDetails key={bookingId} booking={active} closeTo={BASE + suffix} onStatusChange={updateBookingStatus} updating={updatingId === bookingId} apiEnabled={apiLoaded} />
          </div>
        )}
      </div>
    </div>
  );
}
