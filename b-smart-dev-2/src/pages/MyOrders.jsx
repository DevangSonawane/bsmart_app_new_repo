import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { BadgeCheck, Briefcase, Calendar, CalendarPlus, CheckCircle2, ChevronLeft, ChevronRight, ClipboardList, Copy, Download, HelpCircle, KeyRound, Loader2, MessageCircle, Package, ReceiptText, RefreshCw, Search, ShoppingBag, Truck, UserRound, Wallet, XCircle } from 'lucide-react';
import { money } from '../myStore/data/orderFilters';
import orderService from '../services/orderService';
import serviceBookingService from '../services/serviceBookingService';
import influencerProductService from '../services/influencerProductService';
import { fetchWallet } from '../store/walletSlice';
import { StatusBadge } from '../myStore/components/OrderUI';
import { Dropdown } from '../components/productForm/ProductFormFields';

const formatDate = (value) => value ? new Date(value).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Date unavailable';
const canCancel = (status) => ['New', 'Pending', 'Confirmed', 'Processing'].includes(status);
const ACTIVE_STATUSES = ['New', 'Pending', 'Confirmed', 'Processing', 'Shipped', 'In Progress'];
const orderTotal = ({ type, record }) => (type === 'product' ? Number(record.amount || 0) - Number(record.coinsDiscount || 0) : Number(record.amount || 0));
const orderLabel = ({ type, record }) => (type === 'product' ? (record.items || []).map((item) => item.name).join(', ') : record.service);
const TRACKING_STEPS = ['Confirmed', 'Processing', 'Shipped', 'Delivered'];
const isInTransit = (status) => ['Processing', 'Shipped'].includes(status);

function OrderCardSkeleton() {
  const bar = 'animate-pulse rounded bg-gray-100 dark:bg-gray-800';
  return (
    <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm overflow-hidden">
      <div className="flex items-center justify-between gap-2 px-4 sm:px-5 py-4 border-b border-gray-100 dark:border-gray-800">
        <div className="space-y-2"><div className={`${bar} h-3 w-32`} /><div className={`${bar} h-4 w-48`} /></div>
        <div className={`${bar} h-6 w-20 rounded-full`} />
      </div>
      <div className="flex flex-col lg:flex-row gap-4 px-4 sm:px-5 py-4">
        <div className="flex flex-1 items-center gap-4">
          <div className={`${bar} h-24 w-24 rounded-xl shrink-0`} />
          <div className="flex-1 space-y-2"><div className={`${bar} h-4 w-2/3`} /><div className={`${bar} h-3 w-1/3`} /></div>
        </div>
        <div className="flex flex-row flex-wrap lg:flex-col gap-2 lg:w-52 shrink-0">
          <div className={`${bar} h-11 w-full rounded-full`} />
          <div className={`${bar} h-9 w-full rounded-full`} />
        </div>
      </div>
    </div>
  );
}

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
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All statuses');
  const [typeFilter, setTypeFilter] = useState('All');
  const [dateRange, setDateRange] = useState('All time');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(5);
  const [productCatalog, setProductCatalog] = useState({});
  const [copiedSku, setCopiedSku] = useState('');
  const buyerId = user?._id || user?.id;
  const belongsToBuyer = (record) => buyerId && record.buyerId && String(record.buyerId) === String(buyerId);

  const fetchOrders = async () => {
    setLoading(true);
    setError('');
    try {
      const [orders, liveBookings, catalog] = await Promise.all([
        orderService.listBuyer(),
        serviceBookingService.listBuyer(),
        influencerProductService.list().catch(() => []),
      ]);
      setApiOrders(orders);
      setApiBookings(liveBookings);
      setProductCatalog(Object.fromEntries(catalog.map((product) => [String(product.id), product])));
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

  const productCount = orders.filter((order) => order.type === 'product').length;
  const serviceCount = orders.filter((order) => order.type === 'service').length;
  const activeCount = orders.filter((order) => ACTIVE_STATUSES.includes(order.record.status)).length;
  const totalSpent = orders.reduce((sum, order) => sum + orderTotal(order), 0);
  const statusOptions = ['All statuses', ...new Set(orders.map((order) => order.record.status).filter(Boolean))];
  const query = search.trim().toLowerCase();
  const dateRangeDays = { 'Last 7 days': 7, 'Last 30 days': 30, 'Last 90 days': 90 }[dateRange];
  const filteredOrders = orders.filter((order) => {
    const matchesQuery = !query || String(order.record.id).toLowerCase().includes(query) || orderLabel(order).toLowerCase().includes(query);
    const matchesStatus = statusFilter === 'All statuses' || order.record.status === statusFilter;
    const matchesType = typeFilter === 'All' || order.type === typeFilter;
    const matchesDate = !dateRangeDays || (Date.now() - new Date(order.date).getTime()) <= dateRangeDays * 24 * 60 * 60 * 1000;
    return matchesQuery && matchesStatus && matchesType && matchesDate;
  });

  const effectivePageSize = pageSize === 'All' ? Math.max(filteredOrders.length, 1) : pageSize;
  const totalPages = Math.max(1, Math.ceil(filteredOrders.length / effectivePageSize));
  const currentPage = Math.min(page, totalPages);
  const pageOrders = filteredOrders.slice((currentPage - 1) * effectivePageSize, currentPage * effectivePageSize);
  const rangeStart = filteredOrders.length === 0 ? 0 : (currentPage - 1) * effectivePageSize + 1;
  const rangeEnd = Math.min(currentPage * effectivePageSize, filteredOrders.length);
  const pageNumbers = (() => {
    if (totalPages <= 7) return Array.from({ length: totalPages }, (_, i) => i + 1);
    const pages = new Set([1, 2, currentPage - 1, currentPage, currentPage + 1, totalPages - 1, totalPages]);
    return [...pages].filter((n) => n >= 1 && n <= totalPages).sort((a, b) => a - b);
  })();

  const applySearch = (value) => { setSearch(value); setPage(1); };
  const applyStatusFilter = (value) => { setStatusFilter(value); setPage(1); };
  const applyTypeFilter = (value) => { setTypeFilter(value); setPage(1); };
  const applyDateRange = (value) => { setDateRange(value); setPage(1); };
  const applyPageSize = (value) => { setPageSize(value === 'All' ? 'All' : Number(value)); setPage(1); };

  const exportCsv = () => {
    const rows = [
      ['Order ID', 'Type', 'Item(s)', 'Status', 'Date', 'Total'],
      ...filteredOrders.map((order) => [order.record.id, order.type, orderLabel(order), order.record.status, formatDate(order.date), orderTotal(order).toFixed(2)]),
    ];
    const csv = rows.map((row) => row.map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `orders-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const downloadOrderSlip = (order) => {
    const lines = [
      `Order #${order.record.id}`,
      `Date: ${formatDate(order.date)}`,
      `Status: ${order.record.status}`,
      order.record.courier ? `Courier: ${order.record.courier}` : null,
      order.record.trackingNumber ? `Tracking number: ${order.record.trackingNumber}` : null,
      '',
      'Items:',
      ...(order.record.items || []).map((item) => `  - ${item.name} x${item.quantity} - ${money(item.unitPrice * item.quantity)}`),
      '',
      `Total paid: ${money(orderTotal(order))}`,
    ].filter(Boolean);
    const blob = new Blob([lines.join('\n')], { type: 'text/plain;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `order-slip-${order.record.id}.txt`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const downloadCalendarInvite = (record) => {
    const [startTime, endTime] = String(record.time || '').split('-').map((part) => part.trim());
    const toIcsDate = (d, t) => {
      if (!d) return '';
      const parsed = new Date(t ? `${d}T${t}:00` : d);
      if (Number.isNaN(parsed.getTime())) return '';
      return parsed.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
    };
    const dtStart = toIcsDate(record.date, startTime) || toIcsDate(record.date);
    const dtEnd = toIcsDate(record.date, endTime) || dtStart;
    if (!dtStart) return;
    const lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      `UID:${record.id}@b-smart`,
      `DTSTAMP:${toIcsDate(new Date().toISOString().slice(0, 10))}`,
      `DTSTART:${dtStart}`,
      `DTEND:${dtEnd}`,
      `SUMMARY:${record.service}`,
      'DESCRIPTION:Booking made via b_smart Marketplace',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    const blob = new Blob([lines.join('\r\n')], { type: 'text/calendar;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `booking-${record.id}.ics`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const copySku = async (sku) => {
    try {
      await navigator.clipboard?.writeText(sku);
      setCopiedSku(sku);
      window.setTimeout(() => setCopiedSku(''), 1400);
    } catch {
      setCopiedSku('');
    }
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] mx-auto px-4 pt-6">
      {/* Hero */}
      <section className="relative mb-6 overflow-hidden rounded-[28px] bg-gradient-to-r from-pink-50 via-purple-50/70 to-indigo-50 dark:from-gray-900 dark:via-gray-900 dark:to-gray-900 px-6 py-7 sm:px-8 sm:py-8">
        <div className="flex flex-wrap items-start justify-between gap-6">
          <div className="min-w-0 max-w-lg">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/70 dark:bg-white/5 px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-[#9f1239] dark:text-[#fb7185]">
              <ClipboardList size={13} /> Buyer Center
            </span>
            <h1 className="mt-3 text-2xl sm:text-3xl font-extrabold text-gray-900 dark:text-white">My Orders &amp; Purchases</h1>
            <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">Track, manage, and review every product order and service booking you've made on the Marketplace.</p>
            <button type="button" onClick={fetchOrders} className="mt-3 inline-flex items-center gap-1.5 text-xs font-semibold text-[#9f1239] dark:text-[#fb7185]"><RefreshCw size={13} />Refresh</button>
          </div>
          <div className="flex flex-wrap gap-2.5">
            <div className="flex items-center gap-2.5 rounded-2xl bg-white dark:bg-gray-900 shadow-sm px-4 py-3">
              <span className="w-9 h-9 rounded-xl bg-rose-50 dark:bg-rose-900/20 text-[#9f1239] dark:text-[#fb7185] flex items-center justify-center shrink-0"><ShoppingBag size={17} /></span>
              <div><p className="text-sm font-bold text-gray-900 dark:text-white leading-tight">{orders.length} Total</p><p className="text-[11px] text-gray-500 dark:text-gray-400">Purchases made</p></div>
            </div>
            <div className="flex items-center gap-2.5 rounded-2xl bg-white dark:bg-gray-900 shadow-sm px-4 py-3">
              <span className="w-9 h-9 rounded-xl bg-purple-50 dark:bg-purple-900/20 text-insta-purple flex items-center justify-center shrink-0"><Briefcase size={17} /></span>
              <div><p className="text-sm font-bold text-gray-900 dark:text-white leading-tight">{activeCount} Active</p><p className="text-[11px] text-gray-500 dark:text-gray-400">Bookings &amp; orders</p></div>
            </div>
            <div className="flex items-center gap-2.5 rounded-2xl bg-white dark:bg-gray-900 shadow-sm px-4 py-3">
              <span className="w-9 h-9 rounded-xl bg-amber-50 dark:bg-amber-900/20 text-amber-600 flex items-center justify-center shrink-0"><Wallet size={17} /></span>
              <div><p className="text-sm font-bold text-gray-900 dark:text-white leading-tight">{money(totalSpent)}</p><p className="text-[11px] text-gray-500 dark:text-gray-400">Total spent</p></div>
            </div>
          </div>
        </div>
      </section>

      {/* Toolbar */}
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <div className="relative min-w-0 flex-1">
          <Search size={15} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="search"
            aria-label="Search orders"
            placeholder="Search order ID, product, or service..."
            value={search}
            onChange={(event) => applySearch(event.target.value)}
            className="h-11 w-full rounded-full border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-900 pl-10 pr-4 text-sm text-gray-900 dark:text-white placeholder:text-gray-400 outline-none focus:border-[#fa3f5e] focus:bg-white dark:focus:bg-gray-900"
          />
        </div>
        <Dropdown
          className="w-full sm:w-48"
          value={statusFilter === 'All statuses' ? 'Status: All Records' : statusFilter}
          options={statusOptions.map((status) => status === 'All statuses' ? 'Status: All Records' : status)}
          onChange={(option) => applyStatusFilter(option === 'Status: All Records' ? 'All statuses' : option)}
        />
        <Dropdown
          className="w-full sm:w-40"
          value={dateRange}
          options={['All time', 'Last 7 days', 'Last 30 days', 'Last 90 days']}
          onChange={applyDateRange}
        />
        <button type="button" onClick={exportCsv} className="flex h-11 items-center gap-1.5 rounded-full border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-900 px-4 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-200 dark:hover:border-gray-700 transition-colors">
          <Download size={14} /> Export CSV
        </button>
      </div>

      {/* Type tabs */}
      <div className="flex flex-wrap items-center gap-2 mb-6">
        {[
          { key: 'All', label: 'All Orders', count: orders.length },
          { key: 'product', label: 'Products', count: productCount, icon: ShoppingBag },
          { key: 'service', label: 'Services', count: serviceCount, icon: Briefcase },
        ].map(({ key, label, count, icon: TabIcon }) => (
          <button
            key={key}
            type="button"
            onClick={() => applyTypeFilter(key)}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-sm font-semibold transition-colors ${
              typeFilter === key ? 'bg-[#9f1239] text-white' : 'bg-indigo-50/60 dark:bg-gray-900 text-gray-600 dark:text-gray-300 hover:bg-indigo-50 dark:hover:bg-gray-800'
            }`}
          >
            {TabIcon && <TabIcon size={14} />} {label} ({count})
          </button>
        ))}
      </div>

      {error && <p role="alert" className="mb-4 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">{error}</p>}
      {loading && orders.length === 0 ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }, (_, index) => <OrderCardSkeleton key={index} />)}
        </div>
      ) : filteredOrders.length === 0 ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <Package size={36} className="mx-auto text-[#fa3f5e] mb-4" />
          <p className="text-sm text-gray-500 dark:text-gray-400">{orders.length === 0 ? "You haven't placed any orders yet." : 'No orders match your search or filters.'}</p>
          <Link to="/market" className="inline-block mt-5 px-5 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Browse Marketplace</Link>
        </div>
      ) : (
        <div className="space-y-4">
          {loading && <div className="flex items-center gap-2 text-sm text-gray-500 mb-1"><Loader2 size={14} className="animate-spin" />Refreshing...</div>}
          {pageOrders.map(({ type, date, record }) => (
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
                <StatusBadge status={record.status} />
              </div>
              <div className="flex flex-col lg:flex-row gap-4 px-4 sm:px-5 py-4">
                <div className="min-w-0 lg:w-[70%] divide-y divide-gray-100 dark:divide-gray-800">
                  {type === 'product' ? record.items.map((item, index) => {
                    const product = productCatalog[String(item.productId)];
                    return (
                      <div key={`${item.productId}-${index}`} className="flex flex-wrap items-start gap-4 py-3 first:pt-0 last:pb-0">
                        <span className="w-40 h-30 shrink-0 rounded-xl overflow-hidden bg-pink-50 dark:bg-gray-800 text-[#fa3f5e] flex items-center justify-center">
                          {item.image ? <img src={item.image} alt={item.name} className="w-full h-full object-cover" /> : <Package size={28} />}
                        </span>
                        <div className="min-w-0 flex-1">
                          {product?.vendor && (
                            <div className="flex items-center gap-1.5 mb-1.5">
                              <span className="w-5 h-5 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0"><UserRound size={11} className="text-[#fa3f5e]" /></span>
                              <span className="text-xs font-semibold text-gray-600 dark:text-gray-400">{product.vendor}</span>
                              {product.seller?.is_verified && <BadgeCheck size={13} className="text-[#fa3f5e]" />}
                            </div>
                          )}
                          <Link to={`/market/product/${item.productId}`} className="text-sm font-bold text-gray-900 dark:text-white hover:text-[#fa3f5e] break-words">{item.name}</Link>
                          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Qty: {item.quantity}</p>
                          {product?.sku && (
                            <div className="mt-2 inline-flex items-center gap-2 rounded-lg bg-gray-50 dark:bg-gray-800 px-2.5 py-1.5">
                              <KeyRound size={12} className="text-gray-400" />
                              <span className="text-[11px] font-mono font-semibold text-gray-700 dark:text-gray-300">{product.sku}</span>
                              <button type="button" onClick={() => copySku(product.sku)} aria-label="Copy SKU" className="text-gray-400 hover:text-[#fa3f5e]"><Copy size={11} /></button>
                              {copiedSku === product.sku && <span className="text-[10px] font-semibold text-[#fa3f5e]">Copied</span>}
                            </div>
                          )}
                        </div>
                        <span className="text-sm font-semibold text-gray-900 dark:text-white shrink-0">{money(item.unitPrice * item.quantity)}</span>
                      </div>
                    );
                  }) : (
                    <div className="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0">
                      <span className="w-16 h-16 shrink-0 rounded-xl bg-purple-50 dark:bg-gray-800 text-insta-purple flex items-center justify-center"><Briefcase size={24} /></span>
                      <div className="min-w-0 flex-1">
                        <Link to={`/market/service/${record.serviceId}`} className="text-sm font-semibold text-gray-900 dark:text-white hover:text-[#fa3f5e] break-words">{record.service}</Link>
                        <span className="mt-1.5 inline-flex items-center gap-1.5 rounded-full bg-purple-50 dark:bg-purple-900/20 px-2.5 py-1 text-[11px] font-semibold text-insta-purple">
                          <Calendar size={11} /> Scheduled for {formatDate(record.date)}{record.time ? ` · ${record.time}` : ''}
                        </span>
                      </div>
                      <span className="text-sm font-semibold text-gray-900 dark:text-white">{money(record.amount)}</span>
                    </div>
                  )}

                  {type === 'product' && isInTransit(record.status) && (
                    <div className="pt-4 pb-1">
                      {(record.courier || record.trackingNumber) && (
                        <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">
                          {record.courier && <span className="font-semibold text-gray-700 dark:text-gray-300">{record.courier}</span>}
                          {record.courier && record.trackingNumber && ' · '}
                          {record.trackingNumber && <span>Tracking #{record.trackingNumber}</span>}
                        </p>
                      )}
                      <div className="flex items-center">
                        {TRACKING_STEPS.map((step, index) => {
                          const activeIndex = TRACKING_STEPS.indexOf(record.status);
                          const done = activeIndex >= index;
                          return (
                            <React.Fragment key={step}>
                              {index > 0 && <span className={`h-0.5 flex-1 ${activeIndex >= index ? 'bg-[#fa3f5e]' : 'bg-gray-200 dark:bg-gray-700'}`} />}
                              <div className="flex flex-col items-center gap-1 shrink-0">
                                <span className={`flex h-6 w-6 items-center justify-center rounded-full ${done ? 'bg-[#fa3f5e] text-white' : 'bg-gray-200 dark:bg-gray-700 text-gray-400'}`}>
                                  {done ? <CheckCircle2 size={13} /> : <span className="w-1.5 h-1.5 rounded-full bg-current" />}
                                </span>
                                <span className={`text-[10px] font-semibold whitespace-nowrap ${done ? 'text-gray-900 dark:text-white' : 'text-gray-400'}`}>{step}</span>
                              </div>
                            </React.Fragment>
                          );
                        })}
                      </div>
                    </div>
                  )}
                </div>

                <div className="flex flex-row lg:w-[30%] flex-wrap lg:flex-col gap-2.5  shrink-0">
                  {type === 'product' ? (
                    <>
                      <div className="flex gap-2">
                        <Link to={`/market/my-orders/${record.id}`} className="flex flex-1 items-center justify-center gap-1.5 rounded-full bg-gradient-to-r from-[#9f1239] to-[#fa3f5e] px-3.5 h-9 text-xs font-bold text-white">
                          <Truck size={13} /> Track Order
                        </Link>
                        {canCancel(record.status) && (
                          <button type="button" disabled={cancellingId === record.id} onClick={() => cancelOrder(record.id)} className="flex shrink-0 items-center justify-center gap-1 rounded-full border border-red-200 dark:border-red-900/50 px-3 h-9 text-xs font-semibold text-red-500 disabled:opacity-50 hover:bg-red-50 dark:hover:bg-red-900/10">
                            <XCircle size={13} /> {cancellingId === record.id ? 'Cancelling...' : 'Cancel order'}
                          </button>
                        )}
                      </div>
                      <div className="flex gap-2">
                        <button type="button" onClick={() => downloadOrderSlip({ type, date, record })} className="flex flex-1 items-center justify-center gap-1.5 rounded-full border border-gray-200 dark:border-gray-700 px-3 h-9 text-xs font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-600">
                          <ReceiptText size={13} /> Order Slip
                        </button>
                        <Link to="/settings/help" className="flex flex-1 items-center justify-center gap-1.5 rounded-full border border-gray-200 dark:border-gray-700 px-3 h-9 text-xs font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-600">
                          <HelpCircle size={13} /> Need Help?
                        </Link>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="flex gap-2">
                        <Link to="/messages" className="flex flex-1 items-center justify-center gap-1.5 rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange px-3.5 h-9 text-xs font-bold text-white">
                          <MessageCircle size={13} /> Message Provider
                        </Link>
                        {canCancel(record.status) && (
                          <button type="button" disabled={cancellingId === record.id} onClick={() => cancelBooking(record.id)} className="flex shrink-0 items-center justify-center gap-1 rounded-full border border-red-200 dark:border-red-900/50 px-3 h-9 text-xs font-semibold text-red-500 disabled:opacity-50 hover:bg-red-50 dark:hover:bg-red-900/10">
                            <XCircle size={13} /> {cancellingId === record.id ? 'Cancelling...' : 'Cancel booking'}
                          </button>
                        )}
                      </div>
                      <button type="button" onClick={() => downloadCalendarInvite(record)} className="flex items-center justify-center gap-1.5 rounded-full border border-gray-200 dark:border-gray-700 px-3 h-9 text-xs font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-600">
                        <CalendarPlus size={13} /> Add to Calendar
                      </button>
                    </>
                  )}
                </div>
              </div>

              <div className="flex items-center justify-end px-4 sm:px-5 py-3 border-t border-gray-100 dark:border-gray-800 text-sm">
                <span className="text-gray-500 dark:text-gray-400">Total </span>
                <strong className="ml-1.5 text-[#fa3f5e]">{money(type === 'product' ? record.amount - (record.coinsDiscount || 0) : record.amount)}</strong>
              </div>
            </article>
          ))}
        </div>
      )}

      {!loading && filteredOrders.length > 0 && (
        <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2.5 text-xs text-gray-500 dark:text-gray-400">
            <span>Showing {rangeStart}-{rangeEnd} of {filteredOrders.length}</span>
            <Dropdown
              className="w-28"
              value={pageSize === 'All' ? 'Show all' : `${pageSize} / page`}
              options={['5 / page', '10 / page', '20 / page', '50 / page', 'Show all']}
              onChange={(option) => applyPageSize(option === 'Show all' ? 'All' : option.split(' ')[0])}
            />
          </div>
          {pageSize !== 'All' && totalPages > 1 && (
            <div className="flex items-center gap-1.5 rounded-full border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-900 p-1">
              <button
                type="button"
                disabled={currentPage === 1}
                onClick={() => setPage(currentPage - 1)}
                className="flex h-9 items-center gap-1 rounded-full px-3 text-xs font-semibold text-gray-600 dark:text-gray-300 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white dark:hover:bg-gray-800 transition-colors"
              >
                <ChevronLeft size={13} /> Prev
              </button>
              {pageNumbers.map((pageNumber, index) => (
                <React.Fragment key={pageNumber}>
                  {index > 0 && pageNumbers[index - 1] !== pageNumber - 1 && <span className="px-1 text-xs text-gray-400">…</span>}
                  <button
                    type="button"
                    aria-current={pageNumber === currentPage ? 'page' : undefined}
                    onClick={() => setPage(pageNumber)}
                    className={`flex h-9 w-9 items-center justify-center rounded-full text-xs font-bold transition-colors ${pageNumber === currentPage ? 'bg-[#fa3f5e] text-white shadow-sm' : 'text-gray-600 dark:text-gray-300 hover:bg-white dark:hover:bg-gray-800'}`}
                  >
                    {pageNumber}
                  </button>
                </React.Fragment>
              ))}
              <button
                type="button"
                disabled={currentPage === totalPages}
                onClick={() => setPage(currentPage + 1)}
                className="flex h-9 items-center gap-1 rounded-full px-3 text-xs font-semibold text-gray-600 dark:text-gray-300 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white dark:hover:bg-gray-800 transition-colors"
              >
                Next <ChevronRight size={13} />
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
