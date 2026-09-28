import React from 'react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { ArrowLeft, Briefcase, Package } from 'lucide-react';
import { money } from '../myStore/data/orderFilters';

const formatDate = (value) => value ? new Date(value).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Date unavailable';

export default function MyOrders() {
  const user = useSelector((state) => state.auth.userObject);
  const productOrders = useSelector((state) => state.orders.items);
  const bookings = useSelector((state) => state.bookings.items);
  const buyerId = user?._id || user?.id;
  const belongsToBuyer = (record) => buyerId && record.buyerId && String(record.buyerId) === String(buyerId);
  const orders = [
    ...productOrders.filter(belongsToBuyer).map((order) => ({ type: 'product', date: order.createdAt || order.date, record: order })),
    ...bookings.filter(belongsToBuyer).map((booking) => ({ type: 'service', date: booking.requestedAt, record: booking })),
  ].sort((a, b) => new Date(b.date) - new Date(a.date));

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      <Link to="/market" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e] mb-5"><ArrowLeft size={16} />Back to Marketplace</Link>
      <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">My Orders</h1>
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
                  <p className="text-xs text-gray-500 dark:text-gray-400">{type === 'service' ? 'Service booking' : 'Product order'} · {formatDate(date)}</p>
                  <h2 className="text-sm font-bold text-gray-900 dark:text-white mt-1 break-all">Order #{record.id}</h2>
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
                    <div className="min-w-0 flex-1"><Link to={`/market/service/${record.serviceId}`} className="text-sm font-semibold text-gray-900 dark:text-white hover:text-[#fa3f5e] break-words">{record.service}</Link><p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Scheduled for {formatDate(record.date)}{record.time ? ` · ${record.time}` : ''}</p></div>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{money(record.amount)}</span>
                  </div>
                )}
              </div>
              <div className="flex justify-end gap-3 px-4 sm:px-5 py-3 border-t border-gray-100 dark:border-gray-800 text-sm"><span className="text-gray-500 dark:text-gray-400">Total</span><strong className="text-[#fa3f5e]">{money(type === 'product' ? record.amount - (record.coinsDiscount || 0) : record.amount)}</strong></div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
