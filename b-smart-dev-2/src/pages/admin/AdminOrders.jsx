import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { AlertCircle, AlertOctagon, ChevronLeft, ChevronRight, Loader2, RefreshCw, Search } from 'lucide-react';
import orderService from '../../services/orderService';
import { PaymentBadge, StatusBadge } from '../../myStore/components/OrderUI';
import { money, orderDate } from '../../myStore/data/orderFilters';

const ORDER_STATUSES = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
const PAYMENT_STATUSES = ['pending', 'paid', 'failed', 'refunded'];
const LIMIT = 20;

const selectCls = 'rounded-xl border border-gray-200 bg-white px-3 py-2.5 text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-200';
const inputCls = 'rounded-xl border border-gray-200 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 dark:border-gray-800 dark:bg-gray-900 dark:text-white';
const cap = (value) => value.charAt(0).toUpperCase() + value.slice(1);

export default function AdminOrders() {
  const [orders, setOrders] = useState([]);
  const [meta, setMeta] = useState({ total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filters, setFilters] = useState({ status: '', payment_status: '', buyer: '', seller: '', q: '', refund_failed: false });
  const [page, setPage] = useState(1);

  const update = (patch) => { setFilters((current) => ({ ...current, ...patch })); setPage(1); };

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const result = await orderService.adminList({ ...filters, page, limit: LIMIT });
      setOrders(result.orders);
      setMeta({ total: result.total, totalPages: result.totalPages });
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not load orders.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [filters, page]);

  return (
    <div className="max-w-[1450px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Orders</h1>
        <button type="button" onClick={load} className="inline-flex items-center gap-2 text-xs font-semibold text-[#fa3f5e]">
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      <div className="mb-4 flex flex-wrap gap-3">
        <div className="relative min-w-[200px] flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input aria-label="Search orders" value={filters.q} onChange={(e) => update({ q: e.target.value })} placeholder="Order number or payment ID" className={`${inputCls} w-full pl-9`} />
        </div>
        <select aria-label="Order status" value={filters.status} onChange={(e) => update({ status: e.target.value })} className={selectCls}>
          <option value="">All order status</option>
          {ORDER_STATUSES.map((s) => <option key={s} value={s}>{cap(s)}</option>)}
        </select>
        <select aria-label="Payment status" value={filters.payment_status} onChange={(e) => update({ payment_status: e.target.value })} className={selectCls}>
          <option value="">All payment status</option>
          {PAYMENT_STATUSES.map((s) => <option key={s} value={s}>{cap(s)}</option>)}
        </select>
        <input aria-label="Buyer ID" value={filters.buyer} onChange={(e) => update({ buyer: e.target.value.trim() })} placeholder="Buyer ID" className={`${inputCls} w-40`} />
        <input aria-label="Seller ID" value={filters.seller} onChange={(e) => update({ seller: e.target.value.trim() })} placeholder="Seller ID" className={`${inputCls} w-40`} />
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <button
          type="button"
          aria-pressed={filters.refund_failed}
          onClick={() => update({ refund_failed: !filters.refund_failed })}
          className={`inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-sm font-semibold transition-colors ${filters.refund_failed ? 'border-red-500 bg-red-500 text-white' : 'border-red-200 text-red-600 hover:bg-red-50 dark:border-red-900/50 dark:text-red-300 dark:hover:bg-red-900/20'}`}
        >
          <AlertOctagon size={14} /> Refund failed
        </button>
      </div>

      {error && <p role="alert" className="mb-4 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300"><AlertCircle size={15} />{error}</p>}

      <div className="overflow-x-auto rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <table className="w-full min-w-[900px] text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-left text-xs font-medium text-gray-500 dark:border-gray-800 dark:text-gray-400">
              <th className="px-4 py-3.5">Order</th>
              <th className="px-4 py-3.5">Buyer</th>
              <th className="px-4 py-3.5">Total</th>
              <th className="px-4 py-3.5">Payment</th>
              <th className="px-4 py-3.5">Status</th>
              <th className="px-4 py-3.5">Refund</th>
              <th className="px-4 py-3.5">Date</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
            {loading && <tr><td colSpan={7} className="py-12 text-center text-gray-400"><Loader2 size={18} className="mx-auto animate-spin" /></td></tr>}
            {!loading && orders.map((order) => (
              <tr key={order.id} className={order.refundFailed ? 'bg-red-50/50 hover:bg-red-50 dark:bg-red-900/10' : 'hover:bg-gray-50 dark:hover:bg-gray-800/40'}>
                <td className="px-4 py-4"><Link to={`/admin/orders/${order.id}`} className="font-semibold text-[#fa3f5e] hover:underline">#{order.orderNumber}</Link></td>
                <td className="px-4 py-4 text-gray-700 dark:text-gray-300">{order.buyerUsername || '—'}</td>
                <td className="px-4 py-4 font-semibold text-gray-900 dark:text-white">{money(order.amount)}</td>
                <td className="px-4 py-4"><PaymentBadge status={order.paymentStatus} /></td>
                <td className="px-4 py-4"><StatusBadge status={order.status} /></td>
                <td className="px-4 py-4">{order.refundFailed ? <span className="inline-flex items-center gap-1 rounded-md bg-red-500 px-2 py-1 text-[11px] font-bold text-white"><AlertOctagon size={12} /> Refund failed</span> : <span className="text-xs text-gray-400">—</span>}</td>
                <td className="whitespace-nowrap px-4 py-4 text-gray-600 dark:text-gray-300">{orderDate(order.date)}</td>
              </tr>
            ))}
            {!loading && !orders.length && <tr><td colSpan={7} className="py-14 text-center text-gray-400">No orders match these filters.</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="mt-3 flex items-center justify-between gap-3">
        <p className="text-xs text-gray-400">{meta.total} order{meta.total === 1 ? '' : 's'} · Page {page} of {meta.totalPages}</p>
        <div className="flex items-center gap-2">
          <button type="button" aria-label="Previous page" disabled={page <= 1} onClick={() => setPage((p) => p - 1)} className="rounded-lg p-1.5 text-gray-400 hover:bg-gray-50 disabled:opacity-30 dark:hover:bg-gray-800"><ChevronLeft size={16} /></button>
          <button type="button" aria-label="Next page" disabled={page >= meta.totalPages} onClick={() => setPage((p) => p + 1)} className="rounded-lg p-1.5 text-gray-400 hover:bg-gray-50 disabled:opacity-30 dark:hover:bg-gray-800"><ChevronRight size={16} /></button>
        </div>
      </div>
    </div>
  );
}
