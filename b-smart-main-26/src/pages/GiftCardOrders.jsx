import React, { useState, useEffect, useCallback } from 'react';
import {
  ArrowLeft, Loader2, AlertCircle, Gift, Coins,
  CheckCircle2, Clock, XCircle, RefreshCw, PackageSearch,
  Eye, X, Copy, Check,
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import api from '../lib/api';

// ─── Status config ────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { key: '',           label: 'All'        },
  { key: 'pending',    label: 'Pending'    },
  { key: 'processing', label: 'Processing' },
  { key: 'completed',  label: 'Completed'  },
  { key: 'cancelled',  label: 'Cancelled'  },
];

const STATUS_STYLE = {
  pending:    { label: 'Pending',    color: 'text-amber-500',   bg: 'bg-amber-50 dark:bg-amber-500/10',   border: 'border-amber-200 dark:border-amber-500/20',   Icon: Clock        },
  processing: { label: 'Processing', color: 'text-blue-500',    bg: 'bg-blue-50 dark:bg-blue-500/10',     border: 'border-blue-200 dark:border-blue-500/20',     Icon: RefreshCw    },
  completed:  { label: 'Completed',  color: 'text-green-500',   bg: 'bg-green-50 dark:bg-green-500/10',   border: 'border-green-200 dark:border-green-500/20',   Icon: CheckCircle2 },
  cancelled:  { label: 'Cancelled',  color: 'text-red-400',     bg: 'bg-red-50 dark:bg-red-500/10',       border: 'border-red-200 dark:border-red-500/20',       Icon: XCircle      },
};

const getStatus = (status) =>
  STATUS_STYLE[status?.toLowerCase()] || {
    label: status || 'Unknown', color: 'text-gray-400',
    bg: 'bg-gray-50 dark:bg-gray-800', border: 'border-gray-200 dark:border-gray-700', Icon: Clock,
  };

// ─── Voucher status notes (shown when order isn't completed yet) ──────────────
const STATUS_NOTE = {
  pending: {
    title: 'Under Verification',
    message: "Your order is under verification. It'll be ready within 2 hours.",
    Icon: Clock,
    color: 'text-amber-500',
    bg: 'bg-amber-50 dark:bg-amber-500/10',
    border: 'border-amber-200 dark:border-amber-500/20',
  },
  processing: {
    title: 'Still Processing',
    message: 'Your voucher is being generated. Please check back shortly.',
    Icon: RefreshCw,
    color: 'text-blue-500',
    bg: 'bg-blue-50 dark:bg-blue-500/10',
    border: 'border-blue-200 dark:border-blue-500/20',
  },
};

const fieldFallback = (status) =>
  status === 'pending'    ? 'Under verification — ~2 hrs' :
  status === 'processing' ? 'Still processing' :
  '—';

const formatDateOnly = (iso) => {
  if (!iso) return null;
  return new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
};

// ─── Copyable field row ─────────────────────────────────────────────────────────
const CopyableRow = ({ label, value, status }) => {
  const [copied, setCopied] = useState(false);
  const hasValue = !!value;

  const handleCopy = () => {
    if (!hasValue) return;
    navigator.clipboard.writeText(value);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="flex items-center justify-between px-4 py-3 border-b last:border-b-0 border-gray-100 dark:border-white/[0.06]">
      <span className="text-xs text-gray-400 dark:text-gray-500 flex-shrink-0">{label}</span>
      <div className="flex items-center gap-2 min-w-0">
        <span className={`text-sm font-bold truncate ${hasValue ? 'text-gray-900 dark:text-white tracking-wide' : 'text-gray-400 dark:text-gray-500 italic font-medium'}`}>
          {hasValue ? value : fieldFallback(status)}
        </span>
        {hasValue && (
          <button
            onClick={handleCopy}
            className="w-6 h-6 flex items-center justify-center rounded-md bg-gray-100 dark:bg-white/[0.08] hover:bg-gray-200 dark:hover:bg-white/20 transition-colors flex-shrink-0"
          >
            {copied ? <Check size={11} className="text-green-500" /> : <Copy size={11} className="text-gray-500 dark:text-gray-400" />}
          </button>
        )}
      </div>
    </div>
  );
};

// ─── Voucher modal body (shared by mobile sheet and desktop dialog) ───────────
const VoucherModalBody = ({ order }) => {
  const status = order.status?.toLowerCase();
  const note = STATUS_NOTE[status];
  const expiry = formatDateOnly(order.expiry_date);

  return (
    <>
      {note && (
        <div className={`flex items-start gap-2.5 px-4 py-3 rounded-xl border ${note.bg} ${note.border} mb-4`}>
          <note.Icon size={16} className={`${note.color} flex-shrink-0 mt-0.5 ${status === 'processing' ? 'animate-spin' : ''}`} />
          <div>
            <p className={`text-xs font-bold ${note.color}`}>{note.title}</p>
            <p className="text-[11px] text-gray-500 dark:text-gray-400 mt-0.5 leading-relaxed">{note.message}</p>
          </div>
        </div>
      )}

      {order.vendor && (
        <span className="text-xs font-bold text-orange-500 uppercase tracking-widest">{order.vendor}</span>
      )}
      <h2 className="text-xl font-bold text-gray-900 dark:text-white mt-0.5 leading-snug">{order.title || 'Gift Card'}</h2>
      {order.amount != null && (
        <p className="text-lg font-black text-gray-900 dark:text-white mt-1">₹{Number(order.amount).toLocaleString('en-IN')}</p>
      )}

      <div className="mt-4 rounded-2xl border border-gray-100 dark:border-white/[0.07] overflow-hidden">
        <CopyableRow label="Voucher Code" value={order.voucher_code} status={status} />
        <CopyableRow label="PIN" value={order.voucher_pin} status={status} />
        <div className="flex items-center justify-between px-4 py-3">
          <span className="text-xs text-gray-400 dark:text-gray-500">Expiry Date</span>
          <span className={`text-sm font-bold ${expiry ? 'text-gray-900 dark:text-white' : 'text-gray-400 dark:text-gray-500 italic font-medium'}`}>
            {expiry || fieldFallback(status)}
          </span>
        </div>
      </div>

      {order.redeem_steps?.length > 0 && (
        <div className="mt-4 rounded-2xl bg-gray-50 dark:bg-white/[0.03] border border-gray-100 dark:border-white/[0.06] p-4">
          <p className="text-xs font-bold text-gray-700 dark:text-gray-300 mb-2">How to Redeem</p>
          <ul className="space-y-1.5">
            {order.redeem_steps.map((step, i) => (
              <li key={i} className="flex items-start gap-2 text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
                <span className="text-orange-400 mt-0.5">•</span>{step}
              </li>
            ))}
          </ul>
        </div>
      )}
      <div className="h-2" />
    </>
  );
};

// ─── Voucher detail modal — bottom sheet on mobile, centered dialog on desktop ──
const VoucherDetailModal = ({ order, onClose }) => {
  const [visible,  setVisible]  = useState(false);
  const [imgError, setImgError] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true));
    return () => cancelAnimationFrame(id);
  }, []);

  const handleClose = useCallback(() => {
    setVisible(false);
    setTimeout(onClose, 320);
  }, [onClose]);

  useEffect(() => {
    const h = (e) => { if (e.key === 'Escape') handleClose(); };
    document.addEventListener('keydown', h);
    return () => document.removeEventListener('keydown', h);
  }, [handleClose]);

  const hasImage = order.media?.url && !imgError;

  return (
    <>
      {/* Backdrop */}
      <div
        onClick={handleClose}
        className="fixed inset-0 z-[80] transition-all duration-300"
        style={{ background: visible ? 'rgba(0,0,0,0.6)' : 'rgba(0,0,0,0)', backdropFilter: visible ? 'blur(4px)' : 'none' }}
      />

      {/* Mobile bottom sheet */}
      <div
        className={`fixed inset-x-0 bottom-0 z-[80] md:hidden flex flex-col bg-white dark:bg-[#1c1c1e] rounded-t-3xl shadow-2xl max-h-[88dvh] overflow-hidden
          transition-transform duration-300 ease-out will-change-transform
          ${visible ? 'translate-y-0' : 'translate-y-full'}`}
      >
        <div className="flex justify-center pt-3 pb-1 flex-shrink-0">
          <div className="w-10 h-1 rounded-full bg-gray-300 dark:bg-gray-600" />
        </div>

        {hasImage && (
          <div className="w-full flex-shrink-0 overflow-hidden" style={{ maxHeight: 150 }}>
            <img src={order.media.url} alt={order.title} onError={() => setImgError(true)}
              className="w-full object-contain" style={{ maxHeight: 150, background: '#111' }} />
          </div>
        )}

        <button onClick={handleClose}
          className={`absolute z-10 w-8 h-8 rounded-full flex items-center justify-center transition-colors
            ${hasImage ? 'top-5 right-4 bg-black/40 hover:bg-black/60' : 'top-3 right-4 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700'}`}
        >
          <X size={14} className={hasImage ? 'text-white' : 'text-gray-600 dark:text-gray-300'} />
        </button>

        <div className="flex-1 overflow-y-auto px-5 pt-4 pb-4">
          <VoucherModalBody order={order} />
        </div>
      </div>

      {/* Desktop centered dialog */}
      <div
        className={`fixed inset-0 z-[80] hidden md:flex items-center justify-center p-6 transition-all duration-300
          ${visible ? 'opacity-100 scale-100' : 'opacity-0 scale-95'}`}
        style={{ pointerEvents: visible ? 'auto' : 'none' }}
      >
        <div
          className="relative bg-white dark:bg-[#1c1c1e] rounded-2xl shadow-2xl overflow-hidden max-h-[88vh] w-full max-w-md flex flex-col"
          onClick={(e) => e.stopPropagation()}
        >
          <button onClick={handleClose}
            className="absolute top-3 right-3 z-10 w-8 h-8 rounded-full bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 flex items-center justify-center transition-colors"
          >
            <X size={14} className="text-gray-600 dark:text-gray-300" />
          </button>

          {hasImage && (
            <div className="w-full bg-gray-950 flex-shrink-0 overflow-hidden" style={{ maxHeight: 160 }}>
              <img src={order.media.url} alt={order.title} onError={() => setImgError(true)}
                className="w-full object-contain p-4" style={{ maxHeight: 160 }} />
            </div>
          )}

          <div className="flex-1 overflow-y-auto px-6 pt-6 pb-5">
            <VoucherModalBody order={order} />
          </div>
        </div>
      </div>
    </>
  );
};

// ─── Order card ───────────────────────────────────────────────────────────────
const OrderCard = ({ order, onCancel, onDelete, onView, isCancelLoading, isDeleteLoading }) => {
  const st = getStatus(order.status);
  const StatusIcon = st.Icon;

  return (
    <div className="flex flex-col rounded-2xl overflow-hidden bg-white dark:bg-[#1a1a1a] border border-gray-100 dark:border-white/[0.07] shadow-sm hover:shadow-md hover:border-orange-200 dark:hover:border-orange-500/30 transition-all group">
      {/* Image */}
      <div className="w-full bg-gray-950 flex-shrink-0 overflow-hidden relative" style={{ height: 130 }}>
        {order.media?.url ? (
          <img
            src={order.media.url}
            alt={order.title}
            className="w-full h-full object-cover group-hover:scale-[1.04] transition-transform duration-300"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <Gift size={32} className="text-orange-400/60" />
          </div>
        )}
        
        {/* Status badge overlay */}
        <span className={`absolute top-3 right-3 inline-flex items-center gap-1 px-3 py-1 rounded-full text-[10px] font-bold border ${st.color} ${st.bg} ${st.border} backdrop-blur-md`}>
          <StatusIcon size={10} />
          {st.label}
        </span>
      </div>

      {/* Info */}
      <div className="p-3 flex flex-col gap-1.5 flex-1">
        {order.vendor && (
          <span className="text-[10px] font-black text-orange-500 uppercase tracking-wider">{order.vendor}</span>
        )}
        <p className="text-sm font-bold text-gray-900 dark:text-white leading-snug line-clamp-2">
          {order.title || 'Gift Card'}
        </p>

        <div className="flex items-center gap-1">
          <Coins size={11} className="text-orange-400 flex-shrink-0" />
          <span className="text-[11px] text-gray-400 dark:text-gray-500">
            From <span className="font-bold text-orange-500">{Number(order.bcoins || 0).toLocaleString('en-IN')}</span> bCoins
          </span>
        </div>

        {/* Action buttons */}
        <div className="mt-auto pt-2.5">
          {order.status?.toLowerCase() === 'pending' && (
            <>
              <button
                onClick={() => onCancel(order)}
                disabled={isCancelLoading}
                className="w-full py-2.5 rounded-xl border border-red-200 dark:border-red-500/20 bg-red-50 dark:bg-red-500/10 text-red-500 text-xs font-bold transition-all hover:bg-red-100 dark:hover:bg-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isCancelLoading ? <Loader2 size={12} className="animate-spin inline mr-1" /> : null}
                Cancel Order
              </button>
              <button
                onClick={() => onView(order)}
                className="w-full mt-1.5 text-[11px] text-gray-400 dark:text-gray-500 font-semibold hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
              >
                View Status
              </button>
            </>
          )}

          {order.status?.toLowerCase() === 'cancelled' && (
            <button
              onClick={() => onDelete(order)}
              disabled={isDeleteLoading}
              className="w-full py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 text-xs font-bold transition-all hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isDeleteLoading ? <Loader2 size={12} className="animate-spin inline mr-1" /> : null}
              Delete
            </button>
          )}

          {order.status?.toLowerCase() === 'completed' && (
            <button
              onClick={() => onView(order)}
              className="w-full py-2.5 rounded-xl border border-green-200 dark:border-green-500/20 bg-green-50 dark:bg-green-500/10 text-green-600 dark:text-green-400 text-xs font-bold transition-all hover:bg-green-100 dark:hover:bg-green-500/20 flex items-center justify-center gap-1.5"
            >
              <Eye size={12} />
              View Voucher
            </button>
          )}

          {order.status?.toLowerCase() === 'processing' && (
            <button
              onClick={() => onView(order)}
              className="w-full py-2.5 rounded-xl border border-blue-200 dark:border-blue-500/20 bg-blue-50 dark:bg-blue-500/10 text-blue-500 text-xs font-bold transition-all hover:bg-blue-100 dark:hover:bg-blue-500/20 flex items-center justify-center gap-1.5"
            >
              <Eye size={12} />
              View Status
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// ─── Skeleton ─────────────────────────────────────────────────────────────────
const Skeleton = () => (
  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
    {[1, 2, 3, 4, 5, 6].map((i) => (
      <div key={i} className="flex flex-col rounded-2xl overflow-hidden bg-white dark:bg-[#1a1a1a] border border-gray-100 dark:border-white/[0.07] animate-pulse">
        <div className="w-full bg-gray-200 dark:bg-white/10" style={{ height: 130 }} />
        <div className="p-3 space-y-2 flex-1">
          <div className="h-2.5 bg-gray-200 dark:bg-white/10 rounded w-1/4" />
          <div className="h-4 bg-gray-200 dark:bg-white/10 rounded w-3/4" />
          <div className="h-2.5 bg-gray-100 dark:bg-white/[0.06] rounded w-1/2" />
          <div className="mt-auto pt-2.5 h-8 bg-gray-200 dark:bg-white/10 rounded-xl" />
        </div>
      </div>
    ))}
  </div>
);

// ─── Main page ────────────────────────────────────────────────────────────────
export default function GiftCardOrders() {
  const navigate = useNavigate();

  const [status,  setStatus]  = useState('');
  const [orders,  setOrders]  = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');
  const [isCancelLoading, setIsCancelLoading] = useState(false);
  const [isDeleteLoading, setIsDeleteLoading] = useState(false);
  const [activeOrder, setActiveOrder] = useState(null);

  const fetchOrders = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = {};
      if (status) params.status = status;
      const res = await api.get('/gift-card-orders/my', { params });
      const raw = res.data?.data || res.data?.orders || res.data || [];
      setOrders(Array.isArray(raw) ? raw : []);
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to load orders.');
    } finally {
      setLoading(false);
    }
  }, [status]);
  
  const handleCancel = useCallback(async (order) => {
    setIsCancelLoading(true);
    try {
      await api.patch(`/gift-card-orders/${order._id}/cancel`, { status: 'cancelled' });
      fetchOrders();
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to cancel order.');
    } finally {
      setIsCancelLoading(false);
    }
  }, [fetchOrders]);
  
  const handleDelete = useCallback(async (order) => {
    setIsDeleteLoading(true);
    try {
      await api.delete(`/gift-card-orders/${order._id}`);
      fetchOrders();
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to delete order.');
    } finally {
      setIsDeleteLoading(false);
    }
  }, [fetchOrders]);

  useEffect(() => { fetchOrders(); }, [fetchOrders]);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-[#0a0a0a] lg:max-w-[1100px]  lg:mx-auto w-[85%]  pb-28">

      {/* ── Sticky header ── */}
      <div className="sticky top-0 z-20 bg-white/95 dark:bg-[#0a0a0a]/95 backdrop-blur-sm border-b border-gray-100 dark:border-white/[0.06] px-4 pt-3 pb-2">
        <div className="flex items-center gap-3 mb-3">
          <button
            onClick={() => navigate(-1)}
            className="w-8 h-8 flex items-center justify-center rounded-xl bg-gray-100 dark:bg-white/[0.06] hover:bg-gray-200 dark:hover:bg-white/10 transition-colors flex-shrink-0"
          >
            <ArrowLeft size={16} className="text-gray-700 dark:text-white" />
          </button>
          <div className="flex items-center gap-2 flex-1">
            <Gift size={16} className="text-orange-400 flex-shrink-0" />
            <h1 className="text-base font-bold text-gray-900 dark:text-white tracking-tight">My Redemptions</h1>
          </div>
          <button
            onClick={fetchOrders}
            className={`w-8 h-8 flex items-center justify-center rounded-xl bg-gray-100 dark:bg-white/[0.06] hover:bg-gray-200 dark:hover:bg-white/10 transition-colors text-gray-500 dark:text-gray-400 ${loading ? 'animate-spin' : ''}`}
          >
            <RefreshCw size={14} />
          </button>
        </div>

        {/* Status filter chips */}
        <div className="relative -mx-4">
          <div className="flex gap-1.5 overflow-x-auto pb-1 px-4 scrollbar-hide snap-x">
            {STATUS_TABS.map((tab) => (
              <button
                key={tab.key}
                onClick={() => setStatus(tab.key)}
                className={`flex-shrink-0 snap-start px-3.5 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition-all ${
                  status === tab.key
                    ? 'bg-gray-900 dark:bg-white text-white dark:text-black'
                    : 'bg-gray-100 dark:bg-white/[0.07] text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-white/[0.07]'
                }`}
              >
                {tab.label}
              </button>
            ))}
            <div className="flex-shrink-0 w-2" />
          </div>
          <div className="absolute right-0 top-0 bottom-1 w-8 pointer-events-none bg-gradient-to-l from-white dark:from-[#0a0a0a] to-transparent" />
        </div>
      </div>

      {/* ── Content ── */}
      <div className="px-4 pt-4">
        {loading ? (
          <Skeleton />
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-24 gap-3">
            <AlertCircle size={28} className="text-red-400" />
            <p className="text-sm text-red-500 text-center">{error}</p>
            <button onClick={fetchOrders} className="text-xs text-orange-500 font-semibold underline">Retry</button>
          </div>
        ) : orders.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-28 gap-4">
            <div className="w-16 h-16 rounded-2xl bg-orange-50 dark:bg-orange-500/10 flex items-center justify-center">
              <PackageSearch size={28} className="text-orange-400" />
            </div>
            <div className="text-center">
              <p className="text-base font-semibold text-gray-900 dark:text-white">No redemptions yet</p>
              <p className="text-sm text-gray-400 mt-1">
                {status ? `No ${status} orders found` : 'Redeem a gift card to see your orders here'}
              </p>
            </div>
            <button
              onClick={() => navigate('/gift-cards')}
              className="px-5 py-2.5 rounded-xl bg-orange-500 hover:bg-orange-600 text-white text-sm font-bold transition-colors shadow-sm shadow-orange-500/20"
            >
              Browse Gift Cards
            </button>
          </div>
        ) : (
          <>
            <p className="text-xs text-gray-400 dark:text-gray-500 mb-4">
              {orders.length} order{orders.length !== 1 ? 's' : ''}
              {status ? ` · ${status}` : ''}
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {orders.map((order, i) => (
                <OrderCard
                  key={order._id || i}
                  order={order}
                  onCancel={handleCancel}
                  onDelete={handleDelete}
                  onView={setActiveOrder}
                  isCancelLoading={isCancelLoading}
                  isDeleteLoading={isDeleteLoading}
                />
              ))}
            </div>
          </>
        )}
      </div>

      {activeOrder && (
        <VoucherDetailModal order={activeOrder} onClose={() => setActiveOrder(null)} />
      )}
    </div>
  );
}
