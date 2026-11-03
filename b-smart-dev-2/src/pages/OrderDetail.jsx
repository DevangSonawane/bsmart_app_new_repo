import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  AlertTriangle, ArrowLeft, BadgeCheck, CheckCircle2, ChevronRight, Clock3, Copy, CreditCard, HelpCircle,
  KeyRound, LifeBuoy, MapPin, MessageCircle, Package, Printer, RefreshCcw, RefreshCw, ShieldCheck, Truck, UserRound, Wallet, XCircle,
} from 'lucide-react';
import orderService from '../services/orderService';
import socketService from '../services/socketService';
import influencerProductService from '../services/influencerProductService';
import { fetchWallet } from '../store/walletSlice';

const SUPPORT_EMAIL = 'support@bebsmart.in';
const supportMailto = (orderId, subject, extra = '') =>
  `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(`${subject} — Order #${orderId}`)}&body=${encodeURIComponent(`Order ID: ${orderId}\n${extra}\n\nPlease describe your issue below:\n`)}`;

const panel = 'rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900';
const money = (value) => `Rs ${Number(value || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const canCancel = (status) => ['Pending', 'Confirmed', 'Processing', 'New'].includes(status);

const statusSteps = [
  { status: 'Confirmed', label: 'Order Confirmed', icon: CheckCircle2, description: 'Your order has been confirmed and payment verified.' },
  { status: 'Processing', label: 'Processing', icon: Package, description: 'The seller is preparing your order for shipment.' },
  { status: 'Shipped', label: 'Shipped', icon: Truck, description: 'Your package has left the seller and is on its way.' },
  { status: 'Delivered', label: 'Delivered', icon: CheckCircle2, description: 'Package handed off at your delivery address.' },
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

function StatusTimeline({ status, courier, trackingNumber, placedDate, destination, onCopyTracking, trackingCopied }) {
  const normalized = status === 'New' || status === 'Pending' ? 'Confirmed' : status;
  const activeIndex = statusSteps.findIndex((step) => step.status === normalized);
  const cancelled = status === 'Cancelled';
  return (
    <section className={`${panel} p-4 md:p-5`}>
      <div className="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-2">
          <MapPin size={18} className="mt-0.5 text-[#fa3f5e]" />
          <div>
            <h2 className="text-base font-bold text-gray-900 dark:text-white">Delivery Status</h2>
            <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Live tracking for this order.</p>
          </div>
        </div>
        {destination && (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-gray-50 dark:bg-gray-800 px-3 py-1.5 text-xs font-semibold text-gray-600 dark:text-gray-300">
            <MapPin size={12} /> Delivering to {destination}
          </span>
        )}
      </div>
      {cancelled ? (
        <div className="flex items-center gap-3 rounded-xl bg-red-50 p-4 text-sm font-semibold text-red-600 dark:bg-red-900/20 dark:text-red-300">
          <XCircle size={20} />
          This order has been cancelled.
        </div>
      ) : (
        <div className="space-y-0">
          {statusSteps.map((step, index) => {
            const Icon = step.icon;
            const done = activeIndex >= index;
            const current = activeIndex === index;
            return (
              <div key={step.status} className={`relative flex gap-3 pb-6 last:pb-0 ${current ? '-mx-2 rounded-xl bg-pink-50/60 px-2 pt-2 dark:bg-pink-900/10' : ''}`}>
                {index < statusSteps.length - 1 && <span className={`absolute left-5 top-10 bottom-0 w-0.5 ${activeIndex > index ? 'bg-[#fa3f5e]' : 'bg-gray-200 dark:bg-gray-800'}`} />}
                <span className={`relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${done ? 'bg-[#fa3f5e] text-white' : 'bg-gray-100 text-gray-400 dark:bg-gray-800'}`}>
                  <Icon size={18} />
                </span>
                <div className="min-w-0 flex-1 pt-1.5">
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <p className={`text-sm font-bold ${current ? 'text-[#fa3f5e]' : done ? 'text-gray-900 dark:text-white' : 'text-gray-400'}`}>{step.label}</p>
                    {index === 0 && placedDate && <span className="text-xs text-gray-400 shrink-0">{placedDate}</span>}
                  </div>
                  <p className={`mt-0.5 text-xs ${done ? 'text-gray-500 dark:text-gray-400' : 'text-gray-400'}`}>{step.description}</p>
                </div>
              </div>
            );
          })}
        </div>
      )}
      {(courier || trackingNumber) && (
        <div className="mt-2 flex flex-wrap items-center gap-2 rounded-xl bg-gray-50 dark:bg-gray-800/70 p-3">
          {courier && <span className="rounded-md bg-white dark:bg-gray-900 px-2 py-1 text-[11px] font-bold text-gray-700 dark:text-gray-300">{courier}</span>}
          {trackingNumber && (
            <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#fa3f5e] break-all">
              {trackingNumber}
              <button type="button" onClick={onCopyTracking} aria-label="Copy tracking number" className="text-gray-400 hover:text-[#fa3f5e]"><Copy size={12} /></button>
              {trackingCopied && <span className="text-[10px] text-gray-400">Copied</span>}
            </span>
          )}
        </div>
      )}
    </section>
  );
}

function OrderDetailSkeleton() {
  const bar = 'animate-pulse rounded bg-gray-200 dark:bg-gray-800';
  return (
    <div className="min-h-screen bg-gray-50 px-4 pb-24 pt-6 dark:bg-black md:px-6">
      <div className="mx-auto w-full max-w-6xl space-y-5">
        <div className="flex items-center justify-between">
          <div className={`${bar} h-5 w-36`} />
          <div className="flex gap-2"><div className={`${bar} h-9 w-24 rounded-lg`} /><div className={`${bar} h-9 w-24 rounded-lg`} /></div>
        </div>
        <section className={`${panel} p-5`}>
          <div className={`${bar} h-4 w-24 mb-3`} />
          <div className={`${bar} h-7 w-64 mb-2`} />
          <div className={`${bar} h-4 w-40`} />
        </section>
        <section className={`${panel} p-5 space-y-5`}>
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="flex items-center gap-3">
              <div className={`${bar} h-10 w-10 rounded-full shrink-0`} />
              <div className={`${bar} h-4 w-32`} />
            </div>
          ))}
        </section>
        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px]">
          <section className={`${panel} p-5 space-y-4`}>
            {[0, 1].map((i) => (
              <div key={i} className="flex items-center gap-3">
                <div className={`${bar} h-16 w-16 rounded-xl shrink-0`} />
                <div className="flex-1 space-y-2"><div className={`${bar} h-4 w-2/3`} /><div className={`${bar} h-3 w-1/3`} /></div>
              </div>
            ))}
          </section>
          <aside className="space-y-5">
            {[0, 1, 2].map((i) => (
              <section key={i} className={`${panel} p-5 space-y-3`}>
                <div className={`${bar} h-4 w-32`} />
                <div className={`${bar} h-3 w-full`} />
                <div className={`${bar} h-3 w-2/3`} />
              </section>
            ))}
          </aside>
        </div>
      </div>
    </div>
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
  const [trackingCopied, setTrackingCopied] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [productCatalog, setProductCatalog] = useState({});
  const [copiedSku, setCopiedSku] = useState('');

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

  useEffect(() => {
    let active = true;
    influencerProductService.list()
      .then((catalog) => { if (active) setProductCatalog(Object.fromEntries(catalog.map((product) => [String(product.id), product]))); })
      .catch(() => {});
    return () => { active = false; };
  }, []);

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

  const copyTracking = async () => {
    if (!order?.trackingNumber) return;
    try {
      await navigator.clipboard?.writeText(order.trackingNumber);
      setTrackingCopied(true);
      window.setTimeout(() => setTrackingCopied(false), 1400);
    } catch {
      setTrackingCopied(false);
    }
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
    return <OrderDetailSkeleton />;
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
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-100 dark:border-gray-800 pb-3">
          <button type="button" onClick={() => navigate('/market/my-orders')} className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e]">
            <ArrowLeft size={16} />
            Back to My Orders
          </button>
          <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-gray-400 dark:text-gray-500">
            <Package size={13} /> Order #{order.id}
          </span>
        </div>

        {error && <p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-700 dark:border-amber-900/50 dark:bg-amber-900/20 dark:text-amber-300">{error}</p>}
        {order.refundFailed && <p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-700 dark:border-amber-900/50 dark:bg-amber-900/20 dark:text-amber-300">Your refund is being processed manually.</p>}

        <section className={`${panel} p-5`}>
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div className="min-w-0">
              <div className="flex min-w-0 flex-wrap items-center gap-3">
                <h1 className="min-w-0 break-all text-2xl font-bold text-gray-900 dark:text-white">Order #{order.id}</h1>
                <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold uppercase ${order.status === 'Cancelled' ? 'bg-red-50 text-red-500 dark:bg-red-900/20' : 'bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/20'}`}>
                  <span className="h-1.5 w-1.5 rounded-full bg-current" /> {order.status}
                </span>
                <button type="button" onClick={copyOrderId} className="rounded-lg p-1 text-gray-400 hover:bg-gray-50 hover:text-[#fa3f5e] dark:hover:bg-gray-800" aria-label="Copy order id">
                  <Copy size={13} />
                </button>
              </div>
              {copied && <p className="mt-1 text-xs font-semibold text-[#fa3f5e]">Order ID copied.</p>}
              <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-gray-500 dark:text-gray-400">
                <span className="inline-flex items-center gap-1.5"><Clock3 size={13} /> Placed on {placed.date}{placed.time ? ` at ${placed.time}` : ''}</span>
                <span className="inline-flex items-center gap-1.5"><CreditCard size={13} /> Payment: {order.status === 'Cancelled' && order.paymentStatus === 'Paid' ? 'Refund pending' : order.paymentStatus}</span>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-1.5">
              <button type="button" onClick={loadOrder} className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 text-xs font-bold text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800">
                <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
                Refresh
              </button>
              <button type="button" onClick={() => window.print()} className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 text-xs font-bold text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800">
                <Printer size={13} />
                Print Invoice
              </button>
              <Link to="/settings/help" className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-gradient-to-r from-[#9f1239] to-[#fa3f5e] px-3 text-xs font-bold text-white">
                <HelpCircle size={13} />
                Get Help
              </Link>
              {canCancel(order.status) && (
                <button type="button" disabled={cancelling} onClick={cancelOrder} className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-red-200 bg-red-50 px-3 text-xs font-bold text-red-600 disabled:opacity-50 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">
                  <XCircle size={13} />
                  {cancelling ? 'Cancelling...' : 'Cancel order'}
                </button>
              )}
            </div>
          </div>
        </section>

        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px] items-start">
          <StatusTimeline
            status={order.status}
            courier={order.courier}
            trackingNumber={order.trackingNumber}
            placedDate={placed.time ? `${placed.date} · ${placed.time}` : placed.date}
            destination={[order.address?.city, order.address?.region].filter(Boolean).join(', ')}
            onCopyTracking={copyTracking}
            trackingCopied={trackingCopied}
          />

          <aside className="space-y-5">
            <section className={`${panel} p-5`}>
              <div className="mb-4 flex items-center gap-2">
                <CreditCard size={18} className="text-[#fa3f5e]" />
                <h2 className="text-base font-bold">Payment Summary</h2>
              </div>
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between gap-3 text-gray-500 dark:text-gray-400">
                  <dt>Items subtotal ({order.items.length})</dt>
                  <dd className="font-semibold text-gray-900 dark:text-white">{money(order.items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0))}</dd>
                </div>
                <div className="flex justify-between gap-3 text-gray-500 dark:text-gray-400">
                  <dt>Shipping</dt>
                  <dd className="font-semibold text-gray-900 dark:text-white">Free</dd>
                </div>
                {order.coinsDiscount > 0 && (
                  <div className="flex justify-between gap-3 text-insta-purple">
                    <dt>B-Coins discount</dt>
                    <dd className="font-semibold">-{money(order.coinsDiscount)}</dd>
                  </div>
                )}
                <div className="flex justify-between gap-3 border-t border-gray-100 pt-3 text-[#fa3f5e] dark:border-gray-800">
                  <dt className="inline-flex items-center gap-2 font-bold"><Wallet size={15} />Total Paid</dt>
                  <dd className="font-bold">{money(paidTotal)}</dd>
                </div>
              </dl>
            </section>

            <section className={`${panel} p-5`}>
              <div className="mb-4 flex items-center gap-2">
                <MapPin size={18} className="text-[#fa3f5e]" />
                <h2 className="text-base font-bold">Shipping Destination</h2>
              </div>
              <address className="not-italic text-sm leading-6 text-gray-500 dark:text-gray-400">
                <span className="font-bold text-gray-900 dark:text-white">{order.address.name}</span>
                {deliveryLines.map((line) => <React.Fragment key={line}><br />{line}</React.Fragment>)}
                {order.address.email && <><br />{order.address.email}</>}
                {order.address.phone && <><br />{order.address.phone}</>}
              </address>
            </section>
          </aside>
        </div>

        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px] items-start">
          <section className={`${panel} overflow-hidden`}>
            <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4 dark:border-gray-800">
              <h2 className="text-base font-bold">Items in This Order ({order.items.length})</h2>
            </div>
            <div className="divide-y divide-gray-100 dark:divide-gray-800">
              {order.items.map((item, index) => {
                const variantText = item.variant ? [item.variant.color, item.variant.size].filter(Boolean).join(' / ') : '';
                const product = productCatalog[String(item.productId)];
                return (
                  <div key={`${item.productId}-${index}`} className="flex flex-col gap-3 px-5 py-4 sm:flex-row sm:items-start">
                    <OrderItemImage item={item} products={products} />
                    <div className="min-w-0 flex-1">
                      {product?.vendor && (
                        <div className="flex flex-wrap items-center gap-1.5 mb-1.5">
                          <span className="w-5 h-5 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0"><UserRound size={11} className="text-[#fa3f5e]" /></span>
                          <span className="text-xs font-semibold text-gray-600 dark:text-gray-400">{product.vendor}</span>
                          {product.seller?.is_verified && <BadgeCheck size={13} className="text-[#fa3f5e]" />}
                          <Link to="/messages" className="inline-flex items-center gap-1 text-xs font-semibold text-[#fa3f5e] ml-1"><MessageCircle size={12} /> Message Creator</Link>
                        </div>
                      )}
                      <Link to={`/market/product/${item.productId}`} className="text-sm font-bold text-gray-900 hover:text-[#fa3f5e] dark:text-white">{item.name}</Link>
                      <div className="flex flex-wrap items-center gap-1.5 mt-1.5">
                        {variantText && <span className="rounded-md bg-gray-50 dark:bg-gray-800 px-2 py-0.5 text-[11px] font-semibold text-gray-600 dark:text-gray-300">{variantText}</span>}
                        {product?.sku && (
                          <button type="button" onClick={() => copySku(product.sku)} className="inline-flex items-center gap-1 rounded-md bg-gray-50 dark:bg-gray-800 px-2 py-0.5 text-[11px] font-mono font-semibold text-gray-600 dark:text-gray-300">
                            <KeyRound size={10} /> {product.sku} <Copy size={10} />
                          </button>
                        )}
                        {copiedSku === product?.sku && <span className="text-[10px] font-semibold text-[#fa3f5e]">Copied</span>}
                      </div>
                      <p className="mt-1.5 text-xs text-gray-500 dark:text-gray-400">Qty: {item.quantity} x {money(item.unitPrice)}</p>
                    </div>
                    <p className="text-sm font-bold shrink-0">{money(item.unitPrice * item.quantity)}</p>
                  </div>
                );
              })}
            </div>
          </section>

          <section className={`${panel} p-5`}>
            <div className="mb-1 flex items-center gap-2">
              <LifeBuoy size={18} className="text-insta-purple" />
              <h2 className="text-base font-bold">Need Help with Order?</h2>
            </div>
            <p className="mb-4 text-xs leading-5 text-gray-500 dark:text-gray-400">Something not right? Reach out and our support team will take care of it.</p>
            <div className="space-y-2">
              <a href={supportMailto(order.id, 'Missing or damaged package')} className="flex items-center justify-between gap-2 rounded-xl border border-gray-100 dark:border-gray-800 px-3.5 py-3 text-sm font-semibold text-gray-700 dark:text-gray-200 hover:border-gray-200 dark:hover:border-gray-700">
                <span className="inline-flex items-center gap-2"><AlertTriangle size={15} className="text-amber-500" /> Report Missing / Damaged Package</span>
                <ChevronRight size={15} className="text-gray-300" />
              </a>
              <a href={supportMailto(order.id, 'Exchange size or variant')} className="flex items-center justify-between gap-2 rounded-xl border border-gray-100 dark:border-gray-800 px-3.5 py-3 text-sm font-semibold text-gray-700 dark:text-gray-200 hover:border-gray-200 dark:hover:border-gray-700">
                <span className="inline-flex items-center gap-2"><RefreshCcw size={15} className="text-insta-purple" /> Exchange Size or Variant</span>
                <ChevronRight size={15} className="text-gray-300" />
              </a>
              <a href={supportMailto(order.id, 'Return and refund request')} className="flex items-center justify-between gap-2 rounded-xl border border-gray-100 dark:border-gray-800 px-3.5 py-3 text-sm font-semibold text-gray-700 dark:text-gray-200 hover:border-gray-200 dark:hover:border-gray-700">
                <span className="inline-flex items-center gap-2"><Package size={15} className="text-[#fa3f5e]" /> Start Return &amp; Refund Request</span>
                <ChevronRight size={15} className="text-gray-300" />
              </a>
            </div>
            <a href={`mailto:${SUPPORT_EMAIL}`} className="mt-4 block text-center text-sm font-semibold text-[#fa3f5e]">Contact support</a>
            <p className="mt-4 flex items-start gap-2 text-[11px] leading-5 text-gray-400 dark:text-gray-500">
              <ShieldCheck size={14} className="shrink-0 mt-0.5 text-green-500" />
              Your payment is protected until delivery is confirmed.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
