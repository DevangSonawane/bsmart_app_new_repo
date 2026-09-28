import React, { useRef, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Search, ArrowDown, ArrowUp, ChevronLeft, ChevronRight, CalendarDays, X } from 'lucide-react';
import { Dropdown, inputCls } from '../../components/productForm/ProductFormFields';
import OrderDetails from '../components/OrderDetails';
import { OrderProductImage, PaymentBadge } from '../components/OrderUI';
import { filterOrders, ORDER_TABS, money, orderDate } from '../data/orderFilters';

const PAGE_SIZE = 6;
const BASE = '/market/my-store/orders';

export default function StoreOrders() {
  const orders = useSelector((state) => state.orders.items);
  const products = useSelector((state) => state.products.items);
  const { orderId } = useParams();
  const [params, setParams] = useSearchParams();
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState([]);
  const selectAllRef = useRef(null);
  const tab = ORDER_TABS.includes(params.get('tab')) ? params.get('tab') : 'New';
  const search = params.get('search') || '';
  const payment = params.get('payment') || 'All status';
  const from = params.get('from') || '';
  const to = params.get('to') || '';
  const oldest = params.get('sort') === 'oldest';
  const setFilter = (key, value) => {
    setParams((current) => {
      const next = new URLSearchParams(current);
      if (value) next.set(key, value); else next.delete(key);
      return next;
    }, { replace: true });
    setPage(1);
    setSelected([]);
  };
  const filtered = filterOrders(orders, { tab, search, payment, from, to, oldest });
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * PAGE_SIZE;
  const visibleOrders = filtered.slice(start, start + PAGE_SIZE);
  const allSelected = visibleOrders.length > 0 && visibleOrders.every((order) => selected.includes(order.id));
  const someSelected = visibleOrders.some((order) => selected.includes(order.id));
  const suffix = params.size ? `?${params.toString()}` : '';
  const closeTo = BASE + suffix;
  const activeOrder = orders.find((order) => order.id === orderId);
  const toggle = (id) => setSelected((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);

  return (
    <div className="max-w-[1280px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className={orderId ? 'grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_350px] gap-6 items-start' : ''}>
        <section className={`min-w-0 ${orderId ? 'hidden xl:block' : ''}`} aria-label="Orders">
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-5">Orders</h1>
          <div className="flex gap-6 overflow-x-auto border-b border-gray-200 dark:border-gray-800 mb-5">
            {ORDER_TABS.map((value) => <button key={value} type="button" aria-pressed={tab === value} onClick={() => setFilter('tab', value)} className={`pb-3 text-sm font-semibold border-b-2 whitespace-nowrap transition-colors ${tab === value ? 'border-[#fa3f5e] text-[#fa3f5e]' : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white'}`}>{value}</button>)}
          </div>
          <div className="flex flex-wrap gap-3 mb-4">
            <div className="relative flex-1 min-w-[170px]">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input aria-label="Search orders" value={search} onChange={(event) => setFilter('search', event.target.value)} placeholder="Search orders" className={`${inputCls} pl-9 pr-8`} />
              {search && <button type="button" aria-label="Clear search" onClick={() => setFilter('search', '')} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400"><X size={14} /></button>}
            </div>
            <Dropdown className="w-36" value={payment} options={['All status', 'Paid', 'Unpaid', 'Refunded']} onChange={(value) => setFilter('payment', value)} />
            <details className="relative">
              <summary className="list-none cursor-pointer flex items-center gap-2 px-3.5 py-2.5 rounded-lg border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm text-gray-500 dark:text-gray-400"><CalendarDays size={15} />{from || to ? `${from || 'Start'} – ${to || 'End'}` : 'All dates'}</summary>
              <div className="absolute left-0 sm:left-auto sm:right-0 top-full mt-2 p-4 w-64 z-20 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl shadow-xl space-y-3">
                <label className="block text-xs text-gray-500 dark:text-gray-400">From<input type="date" aria-label="Orders from date" value={from} max={to || undefined} onChange={(event) => setFilter('from', event.target.value)} className={`${inputCls} mt-1`} /></label>
                <label className="block text-xs text-gray-500 dark:text-gray-400">To<input type="date" aria-label="Orders to date" value={to} min={from || undefined} onChange={(event) => setFilter('to', event.target.value)} className={`${inputCls} mt-1`} /></label>
                {from && to && from > to && <p role="alert" className="text-xs text-red-500">The end date must be after the start date.</p>}
                <button type="button" onClick={() => { setParams((current) => { const next = new URLSearchParams(current); next.delete('from'); next.delete('to'); return next; }, { replace: true }); setPage(1); setSelected([]); }} className="text-xs font-semibold text-[#fa3f5e]">Clear dates</button>
              </div>
            </details>
          </div>
          {selected.length > 0 && <p className="text-xs text-[#fa3f5e] mb-3" role="status">{selected.length} order{selected.length === 1 ? '' : 's'} selected <button type="button" onClick={() => setSelected([])} className="ml-2 underline">Clear selection</button></p>}
          <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[660px] text-xs">
                <thead><tr className="border-b border-gray-100 dark:border-gray-800 text-gray-500 dark:text-gray-400 text-left">
                  <th className="pl-4 py-3.5 w-9"><input ref={(node) => { selectAllRef.current = node; if (node) node.indeterminate = someSelected && !allSelected; }} type="checkbox" aria-label="Select all visible orders" checked={allSelected} disabled={!visibleOrders.length} onChange={() => setSelected((current) => allSelected ? current.filter((id) => !visibleOrders.some((order) => order.id === id)) : [...new Set([...current, ...visibleOrders.map((order) => order.id)])])} className="accent-[#fa3f5e] rounded" /></th>
                  <th className="px-3 py-3.5 font-medium">Order</th><th className="px-3 py-3.5 font-medium">Items</th><th className="px-3 py-3.5 font-medium">Total</th><th className="px-3 py-3.5 font-medium">Payment</th>
                  <th className="px-3 py-3.5 font-medium" aria-sort={oldest ? 'ascending' : 'descending'}><button type="button" onClick={() => setFilter('sort', oldest ? '' : 'oldest')} className="flex items-center gap-1.5">Date{oldest ? <ArrowUp size={12} /> : <ArrowDown size={12} />}</button></th>
                  <th className="px-4 py-3.5 font-medium text-right">Actions</th>
                </tr></thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                  {visibleOrders.map((order) => <tr key={order.id} className={orderId === order.id || selected.includes(order.id) ? 'bg-pink-50/60 dark:bg-pink-900/10' : 'hover:bg-gray-50 dark:hover:bg-gray-800/40'}>
                    <td className="pl-4 py-5"><input type="checkbox" aria-label={`Select ${order.id}`} checked={selected.includes(order.id)} onChange={() => toggle(order.id)} className="accent-[#fa3f5e] rounded" /></td>
                    <td className="px-3 py-5"><div className="flex items-center gap-2.5"><span className="w-9 h-9 rounded-full bg-gradient-to-br from-insta-purple/15 to-insta-pink/15 text-[#fa3f5e] flex items-center justify-center flex-shrink-0 text-xs font-bold">{order.customer.split(' ').map((part) => part[0]).slice(0, 2).join('')}</span><div className="min-w-[100px]"><Link to={`${BASE}/${order.id}${suffix}`} className="text-gray-500 dark:text-gray-400">Order <span className="font-semibold text-[#fa3f5e]">#{order.id}</span></Link><p className="text-gray-600 dark:text-gray-300 mt-1">{order.customer}</p>{order.status === 'Cancelled' && <p className="text-red-500 mt-1">Cancelled</p>}</div></div></td>
                    <td className="px-3 py-5"><p className="text-gray-500 dark:text-gray-400 mb-2">{order.items.reduce((sum, item) => sum + item.quantity, 0)} item{order.qty === 1 ? '' : 's'}</p><div className="flex gap-1">{order.items.slice(0, 3).map((item) => <OrderProductImage key={item.productId} item={item} products={products} className="w-9 h-9" />)}</div></td>
                    <td className="px-3 py-5 font-semibold text-gray-800 dark:text-gray-200">{money(order.amount)}</td>
                    <td className="px-3 py-5"><PaymentBadge status={order.paymentStatus} /></td>
                    <td className="px-3 py-5 text-gray-600 dark:text-gray-300 whitespace-nowrap">{orderDate(order.date)}<p className="text-[10px] text-gray-400 mt-1">{order.time}</p></td>
                    <td className="px-4 py-5 text-right"><Link to={`${BASE}/${order.id}${suffix}`} aria-label={`View order ${order.id}`} className="inline-flex whitespace-nowrap border border-[#fa3f5e]/40 text-[#fa3f5e] rounded-lg px-3 py-2 font-semibold hover:bg-pink-50 dark:hover:bg-pink-900/20 transition-colors">View order</Link></td>
                  </tr>)}
                  {!visibleOrders.length && <tr><td colSpan={7} className="py-14 text-center text-gray-400">No orders match this view.</td></tr>}
                </tbody>
              </table>
            </div>
            <div className="flex items-center justify-between gap-3 px-4 py-3.5 border-t border-gray-100 dark:border-gray-800">
              <p className="text-[11px] text-gray-400">Showing {filtered.length ? start + 1 : 0}–{Math.min(start + PAGE_SIZE, filtered.length)} of {filtered.length} orders</p>
              <div className="flex items-center gap-2"><button type="button" aria-label="Previous page" disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)} className="p-1 text-gray-400 disabled:opacity-30"><ChevronLeft size={15} /></button><span className="border border-[#fa3f5e]/40 text-[#fa3f5e] px-2 py-1 rounded text-xs">{currentPage}</span><button type="button" aria-label="Next page" disabled={currentPage === totalPages} onClick={() => setPage(currentPage + 1)} className="p-1 text-gray-400 disabled:opacity-30"><ChevronRight size={15} /></button></div>
            </div>
          </div>
        </section>
        {orderId && <OrderDetails key={orderId} order={activeOrder} closeTo={closeTo} />}
      </div>
    </div>
  );
}
