import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { ArrowLeft, Briefcase, Loader2, Package, RefreshCw, XCircle } from 'lucide-react';
import { money } from '../myStore/data/orderFilters';
import orderService from '../services/orderService';
import serviceBookingService from '../services/serviceBookingService';
import { fetchWallet } from '../store/walletSlice';

const formatDate = (value) => value ? new Date(value).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Date unavailable';
const canCancel = (status) => ['New', 'Pending', 'Confirmed', 'Processing'].includes(status);

export default function MyOrders() {
  const dispatch = useDispatch();
  const user = useSelector((state) => state.auth.userObject);
  const productOrders = useSelector((state) => state.orders.items);
  const bookings = useSelector((state) => state.bookings.items);
  const [apiOrders, setApiOrders] = useState([]);
  const [apiBookings, setApiBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [cancellingId, setCancellingId] = useState('');
  const buyerId = user?._id || user?.id;
  const belongsToBuyer = (record) => buyerId && record.buyerId && String(record.buyerId) === String(buyerId);

  const fetchOrders = async () => {
    setLoading(true);
    setError('');
    try {
      const [orders, liveBookings] = await Promise.all([
        orderService.listBuyer(),
        serviceBookingService.listBuyer(),
      ]);
      setApiOrders(orders);
      setApiBookings(liveBookings);
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not load live orders. Showing local orders where available.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchOrders(); }, []);

  const cancelOrder = async (orderId) => {
    setCancellingId(orderId);
    setError('');
    try {
      const updated = await orderService.cancel(orderId);
      setApiOrders((current) => current.map((order) => order.id === orderId ? updated : order));
      dispatch(fetchWallet());
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not cancel this order.');
    } finally {
      setCancellingId('');
    }
  };

  const cancelBooking = async (bookingId) => {
    setCancellingId(bookingId);
    setError('');
    try {
      const updated = await serviceBookingService.cancel(bookingId);
      setApiBookings((current) => current.map((booking) => booking.id === bookingId ? updated : booking));
      dispatch(fetchWallet());
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not cancel this booking.');
    } finally {
      setCancellingId('');
    }
  };

  const liveProductOrders = apiOrders.map((order) => ({ type: 'product', date: order.createdAt || order.date, record: order }));
  const fallbackProductOrders = productOrders.filter(belongsToBuyer).map((order) => ({ type: 'product', date: order.createdAt || order.date, record: order }));
  const liveServiceOrders = apiBookings.map((booking) => ({ type: 'service', date: booking.requestedAt || booking.date, record: booking }));
  const fallbackServiceOrders = bookings.filter(belongsToBuyer).map((booking) => ({ type: 'service', date: booking.requestedAt, record: booking }));
  const orders = [
    ...(apiOrders.length ? liveProductOrders : fallbackProductOrders),
    ...(apiBookings.length ? liveServiceOrders : fallbackServiceOrders),
  ].sort((a, b) => new Date(b.date) - new Date(a.date));

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      <Link to="/market" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e] mb-5"><ArrowLeft size={16} />Back to Marketplace</Link>
      <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">My Orders</h1>
        <button type="button" onClick={fetchOrders} className="inline-flex items-center gap-2 text-xs font-semibold text-[#fa3f5e]"><RefreshCw size={14} />Refresh</button>
      </div>
      {loading && <div className="flex items-center gap-2 text-sm text-gray-500 mb-4"><Loader2 size={16} className="animate-spin" />Loading orders...</div>}
      {error && <p role="alert" className="mb-4 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">{error}</p>}
      {orders.length === 0 ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <Package size={36} className="mx-auto text-[#fa3f5e] mb-4" />
          <p className="text-sm text-gray-500 dark:text-gray-400">You haven't placed any orders yet.</p>
          <Link to="/market" className="inline-block mt-5 px-5 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Browse Marketplace</Link>
        </div>
      ) : (
        <div className="space-y-4">
          {orders.map(({ type, date, record }) => (
            <article key={`${type}-${record.id}`} className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm overflow-hidden">
              <div className="flex flex-wrap items-center justify-between gap-2 px-4 sm:px-5 py-4 border-b border-gray-100 dark:border-gray-800">
                <div className="min-w-0">
                  <p className="text-xs text-gray-500 dark:text-gray-400">{type === 'service' ? 'Service booking' : 'Product order'} - {formatDate(date)}</p>
                  {type === 'product' ? (
                    <Link to={`/market/my-orders/${record.id}`} className="mt-1 block text-sm font-bold text-gray-900 hover:text-[#fa3f5e] dark:text-white break-all">Order #{record.id}</Link>
                  ) : (
                    <h2 className="text-sm font-bold text-gray-900 dark:text-white mt-1 break-all">Order #{record.id}</h2>
                  )}
                </div>
                <span className="rounded-full px-3 py-1 text-xs font-semibold bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">{record.status}</span>
              </div>
              <div className="px-4 sm:px-5 divide-y divide-gray-100 dark:divide-gray-800">
                {type === 'product' ? record.items.map((item, index) => (
                  <div key={`${item.productId}-${index}`} className="flex flex-wrap items-center gap-3 py-4">
                    <span className="w-10 h-10 shrink-0 rounded-lg bg-pink-50 dark:bg-gray-800 text-[#fa3f5e] flex items-center justify-center"><Package size={20} /></span>
                    <div className="min-w-0 flex-1"><Link to={`/market/product/${item.productId}`} className="text-sm font-semibold text-gray-900 dark:text-white hover:text-[#fa3f5e] break-words">{item.name}</Link><p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Qty: {item.quantity}</p></div>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{money(item.unitPrice * item.quantity)}</span>
                  </div>
                )) : (
                  <div className="flex flex-wrap items-center gap-3 py-4">
                    <span className="w-10 h-10 shrink-0 rounded-lg bg-pink-50 dark:bg-gray-800 text-[#fa3f5e] flex items-center justify-center"><Briefcase size={20} /></span>
                    <div className="min-w-0 flex-1"><Link to={`/market/service/${record.serviceId}`} className="text-sm font-semibold text-gray-900 dark:text-white hover:text-[#fa3f5e] break-words">{record.service}</Link><p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Scheduled for {formatDate(record.date)}{record.time ? ` - ${record.time}` : ''}</p></div>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{money(record.amount)}</span>
                  </div>
                )}
              </div>
              <div className="flex flex-wrap items-center justify-end gap-3 px-4 sm:px-5 py-3 border-t border-gray-100 dark:border-gray-800 text-sm">
                {type === 'product' && canCancel(record.status) && <button type="button" disabled={cancellingId === record.id} onClick={() => cancelOrder(record.id)} className="inline-flex items-center gap-1.5 text-xs font-semibold text-red-500 disabled:opacity-50"><XCircle size={14} />{cancellingId === record.id ? 'Cancelling...' : 'Cancel order'}</button>}
                {type === 'service' && canCancel(record.status) && <button type="button" disabled={cancellingId === record.id} onClick={() => cancelBooking(record.id)} className="inline-flex items-center gap-1.5 text-xs font-semibold text-red-500 disabled:opacity-50"><XCircle size={14} />{cancellingId === record.id ? 'Cancelling...' : 'Cancel booking'}</button>}
                {type === 'product' && <Link to={`/market/my-orders/${record.id}`} className="text-xs font-semibold text-[#fa3f5e]">View details</Link>}
                <span className="text-gray-500 dark:text-gray-400">Total</span>
                <strong className="text-[#fa3f5e]">{money(type === 'product' ? record.amount - (record.coinsDiscount || 0) : record.amount)}</strong>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
