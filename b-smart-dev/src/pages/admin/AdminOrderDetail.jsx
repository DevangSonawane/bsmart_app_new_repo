import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { AlertCircle, AlertOctagon, ArrowLeft, CheckCircle2, Loader2, XCircle } from 'lucide-react';
import orderService from '../../services/orderService';
import { PaymentBadge, StatusBadge } from '../../myStore/components/OrderUI';
import { money, orderDate } from '../../myStore/data/orderFilters';
import { COURIERS } from '../../store/ordersSlice';

const NEXT_STATUSES = ['confirmed', 'processing', 'shipped', 'delivered'];
const CANCELLABLE = ['Pending', 'Confirmed', 'Processing'];
const inputCls = 'w-full rounded-xl border border-gray-200 bg-white px-3 py-2.5 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 dark:border-gray-800 dark:bg-gray-900 dark:text-white';
const panel = 'rounded-2xl border border-gray-100 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900';

export default function AdminOrderDetail() {
  const { orderId } = useParams();
  const [order, setOrder] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [nextStatus, setNextStatus] = useState('confirmed');
  const [courier, setCourier] = useState('');
  const [tracking, setTracking] = useState('');
  const [notifyCustomer, setNotifyCustomer] = useState(true);
  const [cancelReason, setCancelReason] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const fresh = await orderService.get(orderId);
      setOrder(fresh);
      setCourier(fresh.courier || '');
      setTracking(fresh.trackingNumber || '');
      setNotifyCustomer(fresh.notifyCustomer);
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not load this order.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [orderId]);

  const submitStatus = async (e) => {
    e.preventDefault();
    if (nextStatus === 'shipped' && (!courier || !tracking.trim())) {
      setError('Courier and tracking number are required to mark an order as shipped.');
      return;
    }
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const updated = await orderService.updateStatus(order.id, nextStatus, {
        ...(courier ? { courier } : {}),
        ...(tracking.trim() ? { tracking_number: tracking.trim() } : {}),
        notify_customer: notifyCustomer,
      });
      setOrder(updated);
      setNotice(`Order marked as ${nextStatus}.`);
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not update the order status.');
    } finally {
      setBusy(false);
    }
  };

  const submitCancel = async () => {
    if (!cancelReason.trim()) {
      setError('Enter a reason to cancel this order.');
      return;
    }
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const updated = await orderService.cancel(order.id, cancelReason.trim());
      setOrder(updated);
      setCancelReason('');
      setNotice('Order cancelled.');
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not cancel this order.');
    } finally {
      setBusy(false);
    }
  };

  if (loading && !order) {
    return <div className="flex min-h-[40vh] items-center justify-center text-gray-400"><Loader2 className="animate-spin" /></div>;
  }
  if (!order) {
    return (
      <div className="max-w-[1450px] ml-auto px-4 md:px-8 pt-6">
        <Link to="/admin/orders" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e]"><ArrowLeft size={16} /> Back to orders</Link>
        {error && <p role="alert" className="mt-4 text-sm text-red-600">{error}</p>}
      </div>
    );
  }

  const canCancel = CANCELLABLE.includes(order.status);

  return (
    <div className="max-w-[1450px] ml-auto px-4 md:px-8 pt-6 pb-10 space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Link to="/admin/orders" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e]"><ArrowLeft size={16} /> Back to orders</Link>
        <button type="button" onClick={load} className="text-xs font-semibold text-[#fa3f5e]">Refresh</button>
      </div>

      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Order #{order.orderNumber}</h1>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Placed {orderDate(order.date)}{order.time ? ` at ${order.time}` : ''} · Buyer {order.buyerUsername || '—'}</p>
      </div>

      {error && <p role="alert" className="flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300"><AlertCircle size={15} />{error}</p>}
      {notice && <p role="status" className="flex items-center gap-2 rounded-xl border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-700 dark:border-green-900/50 dark:bg-green-900/20 dark:text-green-300"><CheckCircle2 size={15} />{notice}</p>}

      {order.refundFailed && (
        <div role="alert" className="rounded-2xl border border-red-300 bg-red-50 p-5 dark:border-red-900/60 dark:bg-red-900/20">
          <p className="flex items-center gap-2 text-sm font-bold text-red-600 dark:text-red-300"><AlertOctagon size={16} /> Refund failed</p>
          {order.refundError && <p className="mt-2 text-sm text-red-700 dark:text-red-200">Error: {order.refundError}</p>}
          <p className="mt-3 text-xs text-red-600/80 dark:text-red-300/80">Mark as refunded manually — this action has no API yet, so it is shown as a warning only.</p>
        </div>
      )}

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="space-y-5">
          <section className={panel}>
            <h2 className="mb-4 text-base font-bold text-gray-900 dark:text-white">Items</h2>
            <ul className="divide-y divide-gray-100 dark:divide-gray-800">
              {order.items.map((item, index) => (
                <li key={`${item.productId}-${index}`} className="flex items-center justify-between py-3 text-sm">
                  <span className="text-gray-700 dark:text-gray-200">{item.name} <span className="text-gray-400">× {item.quantity}</span></span>
                  <span className="font-semibold text-gray-900 dark:text-white">{money(item.unitPrice * item.quantity)}</span>
                </li>
              ))}
            </ul>
            <div className="mt-4 flex items-center justify-between border-t border-gray-100 pt-4 dark:border-gray-800">
              <span className="text-sm font-semibold text-gray-500">Total</span>
              <span className="text-lg font-bold text-gray-900 dark:text-white">{money(order.amount)}</span>
            </div>
          </section>

          <section className={panel}>
            <h2 className="mb-3 text-base font-bold text-gray-900 dark:text-white">Shipping</h2>
            <p className="text-sm text-gray-600 dark:text-gray-300">{order.address.name}<br />{[order.address.street, order.address.city, order.address.region, order.address.postalCode].filter(Boolean).join(', ')}<br />{order.address.country}</p>
            {order.courier && <p className="mt-3 text-sm text-gray-500">{order.courier}{order.trackingNumber ? ` · ${order.trackingNumber}` : ''}</p>}
          </section>
        </div>

        <div className="space-y-5">
          <section className={panel}>
            <h2 className="mb-4 text-base font-bold text-gray-900 dark:text-white">Status</h2>
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <StatusBadge status={order.status} />
              <PaymentBadge status={order.paymentStatus} />
            </div>

            {order.status !== 'Cancelled' && order.status !== 'Delivered' && (
              <form onSubmit={submitStatus} className="space-y-3">
                <label className="block text-xs font-semibold text-gray-500">Next status
                  <select value={nextStatus} onChange={(e) => setNextStatus(e.target.value)} className={`${inputCls} mt-1`}>
                    {NEXT_STATUSES.map((s) => <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>)}
                  </select>
                </label>
                {nextStatus === 'shipped' && (
                  <>
                    <label className="block text-xs font-semibold text-gray-500">Courier *
                      <select value={courier} onChange={(e) => setCourier(e.target.value)} className={`${inputCls} mt-1`}>
                        <option value="">Select courier</option>
                        {COURIERS.map((c) => <option key={c} value={c}>{c}</option>)}
                      </select>
                    </label>
                    <label className="block text-xs font-semibold text-gray-500">Tracking number *
                      <input value={tracking} onChange={(e) => setTracking(e.target.value)} className={`${inputCls} mt-1`} />
                    </label>
                  </>
                )}
                <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                  <input type="checkbox" checked={notifyCustomer} onChange={(e) => setNotifyCustomer(e.target.checked)} className="accent-[#fa3f5e]" />
                  Notify customer
                </label>
                <button type="submit" disabled={busy} className="w-full rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange py-2.5 text-sm font-bold text-white disabled:opacity-60">
                  {busy ? 'Saving…' : 'Update status'}
                </button>
              </form>
            )}
          </section>

          {canCancel && (
            <section className={panel}>
              <h2 className="mb-3 flex items-center gap-2 text-base font-bold text-red-600"><XCircle size={16} /> Cancel order</h2>
              <textarea rows={3} value={cancelReason} onChange={(e) => setCancelReason(e.target.value)} placeholder="Reason for cancelling" className={`${inputCls} resize-none`} />
              <button type="button" disabled={busy} onClick={submitCancel} className="mt-3 w-full rounded-xl border border-red-200 bg-red-50 py-2.5 text-sm font-bold text-red-600 disabled:opacity-60 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">
                Cancel order
              </button>
            </section>
          )}
        </div>
      </div>
    </div>
  );
}
