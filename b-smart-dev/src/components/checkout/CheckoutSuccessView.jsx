import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle2, Copy, Package, ReceiptText } from 'lucide-react';

const panel = 'rounded-xl border border-gray-100 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-950';
const primary = 'rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange focus:outline-none focus-visible:ring-2 focus-visible:ring-insta-pink focus-visible:ring-offset-2 disabled:opacity-40 disabled:cursor-not-allowed';
const money = (value) => `Rs ${Number(value).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

function SuccessProductImage({ item }) {
  const [failed, setFailed] = useState(false);
  const image = item.images?.[0] || item.image;
  return (
    <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-gray-50 dark:bg-slate-900">
      {image && !failed
        ? <img src={image} alt={item.name} onError={() => setFailed(true)} className="h-full w-full object-cover" />
        : <Package size={26} className="text-[#fa3f5e]" />}
    </div>
  );
}

export default function CheckoutSuccessView({
  orderId = 'Processing',
  orderDate = new Date(),
  paymentMethod = 'wallet',
  total = 0,
  items = [],
  orderMessage = '',
}) {
  const [copiedOrderId, setCopiedOrderId] = useState(false);
  const safeDate = orderDate instanceof Date ? orderDate : new Date(orderDate);
  const formattedDate = Number.isNaN(safeDate.getTime())
    ? 'Today'
    : safeDate.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
  const formattedPayment = paymentMethod === 'wallet' ? 'Wallet' : 'Razorpay';

  const copyOrderId = async () => {
    if (!orderId || orderId === 'Processing') return;
    try {
      await navigator.clipboard?.writeText(String(orderId));
      setCopiedOrderId(true);
      window.setTimeout(() => setCopiedOrderId(false), 1400);
    } catch {
      setCopiedOrderId(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 px-4 py-8 text-gray-900 dark:bg-black dark:text-white md:px-6 md:py-10">
      <div className="mx-auto w-full max-w-5xl space-y-6">
        <section className="text-center">
          <span className="mx-auto flex h-24 w-24 items-center justify-center rounded-full bg-pink-50 text-[#fa3f5e] ring-[10px] ring-white dark:bg-[#1b1324] dark:ring-slate-900">
            <CheckCircle2 size={52} strokeWidth={2.4} />
          </span>
          <h1 className="mt-6 text-2xl font-bold text-gray-900 dark:text-white md:text-3xl">Order placed successfully!</h1>
          <p className="mx-auto mt-3 max-w-2xl text-sm leading-6 text-gray-500 dark:text-slate-300 md:text-base">
            Thank you for your order. Your payment has been verified and your order is now confirmed.
          </p>
          {orderMessage && <p className="mt-2 text-sm text-gray-400 dark:text-slate-500">{orderMessage}</p>}
        </section>

        <section className={`${panel} p-4 md:p-5`} aria-label="Order information">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {[
              ['Order ID', orderId],
              ['Order Date', formattedDate],
              ['Payment Method', formattedPayment],
              ['Total Amount', money(total)],
            ].map(([label, value]) => (
              <div key={label} className="rounded-xl border border-gray-100 bg-gray-50 p-4 dark:border-slate-800 dark:bg-slate-900">
                <p className="text-[11px] font-semibold uppercase tracking-wide text-gray-400 dark:text-slate-400">{label}</p>
                <div className="mt-2 flex min-w-0 items-start justify-between gap-2">
                  <p className="min-w-0 flex-1 break-all text-sm font-bold leading-5 text-gray-900 dark:text-white">{value}</p>
                  {label === 'Order ID' && orderId !== 'Processing' && (
                    <button type="button" onClick={copyOrderId} className="shrink-0 rounded-lg p-1.5 text-gray-400 transition-colors hover:bg-white hover:text-[#fa3f5e] dark:text-slate-400 dark:hover:bg-slate-800" aria-label="Copy order id">
                      <Copy size={14} />
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
          {copiedOrderId && <p className="mt-3 text-xs font-semibold text-[#fa3f5e]">Order ID copied.</p>}
        </section>

        <section className={`${panel} overflow-hidden`} aria-label="Order summary">
          <div className="flex items-center justify-between gap-3 border-b border-gray-100 px-4 py-4 dark:border-slate-800 md:px-5">
            <div className="min-w-0">
              <h2 className="text-base font-bold text-gray-900 dark:text-white">Order Summary</h2>
              <p className="mt-1 text-xs text-gray-500 dark:text-slate-400">{items.length} {items.length === 1 ? 'item' : 'items'} purchased</p>
            </div>
            <ReceiptText size={22} className="text-[#fa3f5e]" />
          </div>
          <div className="divide-y divide-gray-100 dark:divide-slate-800">
            {items.length ? items.map((item) => {
              const variantText = item.variant ? [item.variant.color, item.variant.size].filter(Boolean).join(' / ') : '';
              return (
                <div key={`${item.productId}-${item.name}`} className="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center md:px-5">
                  <SuccessProductImage item={item} />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold text-gray-900 dark:text-white">{item.name}</p>
                    {variantText && <p className="mt-1 text-xs text-gray-500 dark:text-slate-400">Variant: {variantText}</p>}
                    <p className="mt-1 text-xs text-gray-500 dark:text-slate-400">Qty: {item.quantity}</p>
                  </div>
                  <p className="text-sm font-bold text-gray-900 dark:text-white">{money(Number(item.unitPrice || 0) * Number(item.quantity || 1))}</p>
                </div>
              );
            }) : (
              <p className="px-4 py-6 text-sm text-gray-500 dark:text-slate-400 md:px-5">Order details are being prepared. You can view the full order in My Orders.</p>
            )}
          </div>
        </section>

        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-center">
          <Link to="/market" className="flex min-h-11 items-center justify-center rounded-lg border border-gray-200 px-6 py-3 text-sm font-semibold text-gray-700 transition-colors hover:border-gray-300 hover:bg-white dark:border-slate-700 dark:text-white dark:hover:border-slate-500 dark:hover:bg-slate-900">
            Continue Shopping
          </Link>
          <Link to="/market/my-orders" className={`${primary} flex min-h-11 items-center justify-center px-6 py-3`}>
            View My Orders
          </Link>
        </div>
      </div>
    </div>
  );
}
