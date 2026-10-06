import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  ArrowLeft, CheckCircle2, Clock3, Copy, CreditCard, Loader2,
  MapPin, Package, RefreshCw, Truck, Wallet, XCircle,
} from 'lucide-react';
import orderService from '../services/orderService';
import socketService from '../services/socketService';
import { fetchWallet } from '../store/walletSlice';

const panel = 'rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900';
const money = (value) => `Rs ${Number(value || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const canCancel = (status) => ['Pending', 'Confirmed', 'Processing', 'New'].includes(status);

const statusSteps = [
  { label: 'Confirmed', icon: CheckCircle2 },
  { label: 'Processing', icon: Package },
  { label: 'Shipped', icon: Truck },
  { label: 'Delivered', icon: CheckCircle2 },
];

const formatDateTime = (value) => {
  if (!value) return { date: 'Date unavailable', time: '' };
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return { date: 'Date unavailable', time: '' };
  return {
    date: date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }),
    time: date.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' }),
  };
};

function OrderItemImage({ item, products }) {
  const product = products.find((entry) => String(entry.id) === String(item.productId));
  const image = typeof item.image === 'string' ? item.image : product?.images?.[0];
  const [failed, setFailed] = useState(false);
  return (
    <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-xl border border-pink-100 bg-pink-50 text-[#fa3f5e] dark:border-gray-800 dark:bg-gray-800">
      {image && !failed
        ? <img src={image} alt={item.name} onError={() => setFailed(true)} className="h-full w-full object-cover" />
        : <Package size={24} />}
    </div>
  );
}

function StatusTimeline({ status }) {
  const normalized = status === 'New' || status === 'Pending' ? 'Confirmed' : status;
  const activeIndex = statusSteps.findIndex((step) => step.label === normalized);
  const cancelled = status === 'Cancelled';
  return (
    <section className={`${panel} p-4 md:p-5`}>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-base font-bold text-gray-900 dark:text-white">Order progress</h2>
          <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Track where your order is right now.</p>
        </div>
        <span className={`rounded-full px-3 py-1 text-xs font-bold ${cancelled ? 'bg-red-50 text-red-500 dark:bg-red-900/20' : 'bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/20'}`}>
          {status}
        </span>
      </div>
      {cancelled ? (
        <div className="flex items-center gap-3 rounded-xl bg-red-50 p-4 text-sm font-semibold text-red-600 dark:bg-red-900/20 dark:text-red-300">
          <XCircle size={20} />
          This order has been cancelled.
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-4">
          {statusSteps.map((step, index) => {
            const Icon = step.icon;
            const done = activeIndex >= index;
            const current = activeIndex === index;
            return (
              <div key={step.label} className="relative flex items-center gap-3 md:block">
                {index < statusSteps.length - 1 && <span className={`hidden md:block absolute left-[calc(50%+18px)] right-[calc(-50%+18px)] top-5 h-0.5 ${done && activeIndex > index ? 'bg-[#fa3f5e]' : 'bg-gray-200 dark:bg-gray-800'}`} />}
                <span className={`relative z-10 flex h-10 w-10 items-center justify-center rounded-full ${done ? 'bg-[#fa3f5e] text-white' : 'bg-gray-100 text-gray-400 dark:bg-gray-800'}`}>
                  <Icon size={18} />
                </span>
                <div className="min-w-0 md:mt-3">
                  <p className={`text-sm font-bold ${done ? 'text-gray-900 dark:text-white' : 'text-gray-400'}`}>{step.label}</p>
                  <p className="mt-0.5 text-xs text-gray-400">{current ? 'Current step' : done ? 'Completed' : 'Waiting'}</p>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </section>
  );
}

export default function OrderDetail() {
  const { orderId } = useParams();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const products = useSelector((state) => state.products.items);
  const fallbackOrder = useSelector((state) => state.orders.items.find((order) => String(order.id) === String(orderId)));
  const [order, setOrder] = useState(fallbackOrder || null);
  const [loading, setLoading] = useState(!fallbackOrder);
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(false);
  const [cancelling, setCancelling] = useState(false);

  const paidTotal = useMemo(() => Math.max(0, Number(order?.amount || 0) - Number(order?.coinsDiscount || 0)), [order]);
  const placed = formatDateTime(order?.createdAt || order?.date);
  const deliveryLines = [
    order?.address?.street,
    [order?.address?.city, order?.address?.region, order?.address?.postalCode].filter(Boolean).join(', '),
    order?.address?.country,
  ].filter(Boolean);

  const loadOrder = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const liveOrder = await orderService.get(orderId);
      setOrder(liveOrder);
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not load this order. Showing saved details if available.');
    } finally {
      setLoading(false);
    }
  }, [orderId]);

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  }, [orderId]);

  useEffect(() => { loadOrder(); }, [loadOrder]);

  useEffect(() => {
    const onStatusUpdated = (payload) => {
      if (String(payload?.orderId ?? payload?.id ?? payload?._id ?? orderId) === String(orderId)) loadOrder();
    };
    socketService.on('order-status-updated', onStatusUpdated);
    return () => socketService.off('order-status-updated', onStatusUpdated);
  }, [orderId, loadOrder]);

  const copyOrderId = async () => {
    try {
      await navigator.clipboard?.writeText(String(order?.id || orderId));
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1400);
    } catch {
      setCopied(false);
    }
  };

  const cancelOrder = async () => {
    if (!order || cancelling) return;
    setCancelling(true);
    setError('');
    try {
      const updated = await orderService.cancel(order.id);
      setOrder(updated);
      dispatch(fetchWallet());
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not cancel this order.');
    } finally {
      setCancelling(false);
    }
  };

  if (loading && !order) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gray-50 dark:bg-black">
        <div className="flex flex-col items-center gap-3 text-sm text-gray-500 dark:text-gray-400">
          <Loader2 size={34} className="animate-spin text-[#fa3f5e]" />
          Loading order details...
        </div>
      </div>
    );
  }

  if (!order) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-gray-50 px-4 text-center dark:bg-black">
        <Package size={36} className="text-[#fa3f5e]" />
        <h1 className="text-lg font-bold text-gray-900 dark:text-white">Order not found</h1>
        <p className="text-sm text-gray-500 dark:text-gray-400">{error || 'This order could not be opened.'}</p>
        <Link to="/market/my-orders" className="text-sm font-semibold text-[#fa3f5e]">Back to My Orders</Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 px-4 pb-24 pt-6 text-gray-900 dark:bg-black dark:text-white md:px-6">
      <div className="mx-auto w-full max-w-6xl space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <button type="button" onClick={() => navigate('/market/my-orders')} className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e]">
            <ArrowLeft size={16} />
            Back to My Orders
          </button>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" onClick={loadOrder} className="inline-flex min-h-10 items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 text-xs font-bold text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800">
              <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
              Refresh
            </button>
            {canCancel(order.status) && (
              <button type="button" disabled={cancelling} onClick={cancelOrder} className="inline-flex min-h-10 items-center gap-2 rounded-lg border border-red-200 bg-red-50 px-3 text-xs font-bold text-red-600 disabled:opacity-50 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">
                <XCircle size={14} />
                {cancelling ? 'Cancelling...' : 'Cancel order'}
              </button>
            )}
          </div>
        </div>

        {error && <p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-700 dark:border-amber-900/50 dark:bg-amber-900/20 dark:text-amber-300">{error}</p>}
        {order.refundFailed && <p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-700 dark:border-amber-900/50 dark:bg-amber-900/20 dark:text-amber-300">Your refund is being processed manually.</p>}

        <section className={`${panel} overflow-hidden`}>
          <div className="flex flex-col gap-4 border-b border-gray-100 p-5 dark:border-gray-800 lg:flex-row lg:items-center lg:justify-between">
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-gray-400">Order details</p>
              <div className="mt-2 flex min-w-0 flex-wrap items-center gap-2">
                <h1 className="min-w-0 break-all text-2xl font-bold text-gray-900 dark:text-white">Order #{order.id}</h1>
                <button type="button" onClick={copyOrderId} className="rounded-lg p-1.5 text-gray-400 hover:bg-gray-50 hover:text-[#fa3f5e] dark:hover:bg-gray-800" aria-label="Copy order id">
                  <Copy size={16} />
                </button>
              </div>
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Placed on {placed.date}{placed.time ? ` at ${placed.time}` : ''}</p>
              {copied && <p className="mt-2 text-xs font-semibold text-[#fa3f5e]">Order ID copied.</p>}
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:min-w-[520px]">
              <div className="rounded-xl bg-gray-50 p-3 dark:bg-gray-800/70">
                <p className="text-[11px] font-bold uppercase text-gray-400">Items</p>
                <p className="mt-1 text-sm font-bold">{order.items.length}</p>
              </div>
              <div className="rounded-xl bg-gray-50 p-3 dark:bg-gray-800/70">
                <p className="text-[11px] font-bold uppercase text-gray-400">Payment</p>
                <p className="mt-1 text-sm font-bold">{order.status === 'Cancelled' && order.paymentStatus === 'Paid' ? 'Refund pending' : order.paymentStatus}</p>
              </div>
              <div className="rounded-xl bg-gray-50 p-3 dark:bg-gray-800/70">
                <p className="text-[11px] font-bold uppercase text-gray-400">Status</p>
                <p className="mt-1 text-sm font-bold">{order.status}</p>
              </div>
              <div className="rounded-xl bg-gray-50 p-3 dark:bg-gray-800/70">
                <p className="text-[11px] font-bold uppercase text-gray-400">Total</p>
                <p className="mt-1 text-sm font-bold">{money(paidTotal)}</p>
              </div>
            </div>
          </div>
        </section>

        <StatusTimeline status={order.status} />

        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px]">
          <section className={`${panel} overflow-hidden`}>
            <div className="border-b border-gray-100 px-5 py-4 dark:border-gray-800">
              <h2 className="text-base font-bold">Purchased items</h2>
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Products included in this order.</p>
            </div>
            <div className="divide-y divide-gray-100 dark:divide-gray-800">
              {order.items.map((item, index) => {
                const variantText = item.variant ? [item.variant.color, item.variant.size].filter(Boolean).join(' / ') : '';
                return (
                  <div key={`${item.productId}-${index}`} className="flex flex-col gap-3 px-5 py-4 sm:flex-row sm:items-center">
                    <OrderItemImage item={item} products={products} />
                    <div className="min-w-0 flex-1">
                      <Link to={`/market/product/${item.productId}`} className="text-sm font-bold text-gray-900 hover:text-[#fa3f5e] dark:text-white">{item.name}</Link>
                      {variantText && <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Variant: {variantText}</p>}
                      <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Qty: {item.quantity} x {money(item.unitPrice)}</p>
                    </div>
                    <p className="text-sm font-bold">{money(item.unitPrice * item.quantity)}</p>
                  </div>
                );
              })}
            </div>
          </section>

          <aside className="space-y-5">
            <section className={`${panel} p-5`}>
              <div className="mb-4 flex items-center gap-2">
                <MapPin size={18} className="text-[#fa3f5e]" />
                <h2 className="text-base font-bold">Delivery address</h2>
              </div>
              <address className="not-italic text-sm leading-6 text-gray-500 dark:text-gray-400">
                <span className="font-bold text-gray-900 dark:text-white">{order.address.name}</span>
                {deliveryLines.map((line) => <React.Fragment key={line}><br />{line}</React.Fragment>)}
              </address>
            </section>

            <section className={`${panel} p-5`}>
              <div className="mb-4 flex items-center gap-2">
                <CreditCard size={18} className="text-[#fa3f5e]" />
                <h2 className="text-base font-bold">Payment summary</h2>
              </div>
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between gap-3 text-gray-500 dark:text-gray-400">
                  <dt>Payment received</dt>
                  <dd className="font-semibold text-gray-900 dark:text-white">{money(order.amount)}</dd>
                </div>
                <div className="flex justify-between gap-3 text-insta-purple">
                  <dt>B-Coins discount</dt>
                  <dd className="font-semibold">-{money(order.coinsDiscount)}</dd>
                </div>
                <div className="flex justify-between gap-3 border-t border-gray-100 pt-3 text-[#fa3f5e] dark:border-gray-800">
                  <dt className="inline-flex items-center gap-2 font-bold"><Wallet size={15} />Paid total</dt>
                  <dd className="font-bold">{money(paidTotal)}</dd>
                </div>
              </dl>
            </section>

            <section className={`${panel} p-5`}>
              <div className="mb-4 flex items-center gap-2">
                <Clock3 size={18} className="text-[#fa3f5e]" />
                <h2 className="text-base font-bold">Need help?</h2>
              </div>
              <p className="text-sm leading-6 text-gray-500 dark:text-gray-400">Keep your order ID ready if you contact support. You can refresh this page anytime for the latest status.</p>
            </section>
          </aside>
        </div>
      </div>
    </div>
  );
}
