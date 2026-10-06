import React, { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  Bell,
  Check,
  Coins,
  Copy,
  CreditCard,
  Gift,
  HelpCircle,
  MapPin,
  MoreHorizontal,
  Package,
  PackageCheck,
  Phone,
  ReceiptText,
  RotateCw,
  Scale,
  ShieldCheck,
  Truck,
  UserRound,
  Wallet,
  X,
} from 'lucide-react';
import { Dropdown, inputCls, labelCls } from '../../components/productForm/ProductFormFields';
import { COURIERS, canShipOrder, shipOrder, updateOrderFulfillment } from '../../store/ordersSlice';
import { OrderProductImage, PaymentBadge, StatusBadge } from './OrderUI';
import { money, orderDate } from '../data/orderFilters';

const STATUS_OPTIONS = ['Confirmed', 'Processing', 'Shipped', 'Delivered'];

function InfoCard({ label, value, helper, icon: Icon }) {
  return (
    <div className="rounded-xl border border-blue-100 bg-white p-4 shadow-sm dark:border-gray-800 dark:bg-gray-900">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[10px] font-bold uppercase tracking-wide text-slate-400">{label}</p>
          <p className="mt-3 break-words text-lg font-bold text-gray-950 dark:text-white">{value}</p>
          {helper && <p className="mt-1 text-[11px] font-medium text-slate-500 dark:text-gray-400">{helper}</p>}
        </div>
        {Icon && <Icon size={17} className="mt-0.5 flex-shrink-0 text-[#fa3f5e]" />}
      </div>
    </div>
  );
}

function Panel({ title, subtitle, icon: Icon, action, children, className = '' }) {
  return (
    <section className={`overflow-hidden rounded-xl border border-blue-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900 ${className}`}>
      <div className="flex items-start justify-between gap-3 border-b border-blue-50 px-5 py-4 dark:border-gray-800">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            {Icon && <Icon size={16} className="text-[#fa3f5e]" />}
            <h3 className="text-sm font-bold text-gray-950 dark:text-white">{title}</h3>
          </div>
          {subtitle && <p className="mt-1 text-[11px] leading-5 text-slate-500 dark:text-gray-400">{subtitle}</p>}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

function Toggle({ checked, onChange, label }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={onChange}
      className={`h-7 w-12 rounded-full p-0.5 transition-colors ${checked ? 'bg-[#d90445]' : 'bg-gray-300 dark:bg-gray-700'}`}
    >
      <span className={`block h-6 w-6 rounded-full bg-white shadow transition-transform ${checked ? 'translate-x-5' : ''}`} />
    </button>
  );
}

const initials = (name = 'Customer') => String(name)
  .split(' ')
  .filter(Boolean)
  .map((part) => part[0])
  .slice(0, 2)
  .join('');

export default function OrderDetails({ order, closeTo, onStatusChange, onFulfillmentChange, updating = false, apiEnabled = false }) {
  const dispatch = useDispatch();
  const products = useSelector((state) => state.products.items);
  const headingRef = useRef(null);
  const [selectedStatus, setSelectedStatus] = useState(
    order && !['Pending', 'New'].includes(order.status) ? order.status : 'Confirmed'
  );
  const [syncedStatus, setSyncedStatus] = useState(order?.status);
  if (order && order.status !== syncedStatus) {
    setSyncedStatus(order.status);
    if (!['Pending', 'New'].includes(order.status)) setSelectedStatus(order.status);
  }

  useEffect(() => { headingRef.current?.focus({ preventScroll: true }); }, [order?.id]);

  if (!order) {
    return (
      <aside className="rounded-2xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 ref={headingRef} tabIndex={-1} className="font-bold text-gray-900 outline-none dark:text-white">Order not found</h2>
        <Link to={closeTo} className="mt-3 inline-block text-sm text-[#fa3f5e]">Back to orders</Link>
      </aside>
    );
  }

  const editable = ['Pending', 'Confirmed', 'Processing'].includes(order.status);
  const update = (changes) => {
    if (apiEnabled) onFulfillmentChange?.(order.id, changes);
    else dispatch(updateOrderFulfillment({ id: order.id, ...changes }));
  };
  const setStatus = (status) => {
    if (apiEnabled) {
      onStatusChange?.(order.id, status, {
        courier: order.courier,
        tracking_number: order.trackingNumber,
        confirmed_items: order.confirmed,
        packed: order.packed,
        notify_customer: order.notifyCustomer,
      });
    } else if (status === 'Shipped') dispatch(shipOrder(order.id));
  };
  const needsShippingInfo = selectedStatus === 'Shipped';
  const canSubmitStatus = !needsShippingInfo || (order.courier && order.trackingNumber?.trim());
  const handleUpdateStatus = () => {
    if (apiEnabled) {
      onStatusChange?.(order.id, selectedStatus, {
        courier: order.courier,
        tracking_number: order.trackingNumber,
        notify_customer: order.notifyCustomer,
      });
    } else if (selectedStatus === 'Shipped') dispatch(shipOrder(order.id));
  };

  const earnings = Math.max(0, order.amount - order.coinsDiscount);
  const itemCount = order.items.reduce((sum, item) => sum + item.quantity, 0);
  const uniqueItems = order.items.length;
  const progressSteps = ['Confirmed', 'Processing', 'Shipped', 'Delivered'];
  const normalizedStatus = ['Pending', 'New'].includes(order.status) ? 'Confirmed' : order.status;
  const activeStep = progressSteps.indexOf(normalizedStatus);
  const cancelled = order.status === 'Cancelled';
  const canAdvanceToDelivered = order.status === 'Shipped';
  const orderTime = order.time || '10:42 AM';
  const customerEmail = order.email || `${String(order.customer || 'customer').toLowerCase().replace(/\s+/g, '.')}@example.com`;
  const customerPhone = order.phone || '+91 98201 88492';

  const copyOrderId = async () => {
    try {
      await navigator.clipboard?.writeText(String(order.id));
    } catch {
      // Copy is a convenience action; silently ignore browsers without clipboard access.
    }
  };

  return (
    <aside aria-label="Order details" className="space-y-5">
      <section className="space-y-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <h2 ref={headingRef} tabIndex={-1} className="text-2xl font-bold text-gray-950 outline-none dark:text-white">Order details</h2>
              <PaymentBadge status={order.paymentStatus} />
              <StatusBadge status={order.status} />
            </div>
            <div className="mt-2 flex min-w-0 flex-wrap items-center gap-2 text-xs text-slate-600 dark:text-gray-400">
              <span>Order</span>
              <span className="rounded-md bg-pink-50 px-2 py-1 font-bold text-[#fa3f5e] dark:bg-pink-900/20">#{order.id}</span>
              <button type="button" onClick={copyOrderId} aria-label="Copy order id" className="rounded-lg p-1.5 text-gray-400 transition hover:bg-pink-50 hover:text-[#fa3f5e] dark:hover:bg-pink-900/20">
                <Copy size={14} />
              </button>
              <span className="text-slate-300">-</span>
              <span>Placed on {orderDate(order.date)} at {orderTime}</span>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="inline-flex items-center gap-2 rounded-xl border border-blue-100 bg-white px-3 py-2 text-xs font-bold text-gray-700 shadow-sm transition hover:border-[#fa3f5e]/30 hover:text-[#fa3f5e] dark:border-gray-800 dark:bg-gray-950 dark:text-gray-300">
              <HelpCircle size={14} />
              Customer Help
            </button>
            <button type="button" className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-blue-100 bg-white text-gray-500 shadow-sm transition hover:border-[#fa3f5e]/30 hover:text-[#fa3f5e] dark:border-gray-800 dark:bg-gray-950" aria-label="More order actions">
              <MoreHorizontal size={16} />
            </button>
            <Link to={closeTo} aria-label="Close order details" className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-blue-100 bg-white text-gray-500 shadow-sm transition hover:border-[#fa3f5e]/30 hover:text-[#fa3f5e] dark:border-gray-800 dark:bg-gray-950">
              <X size={16} />
            </Link>
          </div>
        </div>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <InfoCard label="Customer" value={order.customer} helper="3rd Order (Returning)" icon={UserRound} />
          <InfoCard label="Items" value={`${itemCount} item${itemCount === 1 ? '' : 's'}`} helper={`${uniqueItems} unique line item${uniqueItems === 1 ? '' : 's'}`} icon={Package} />
          <InfoCard label="Total" value={money(order.amount)} helper="Prepaid via UPI QR" icon={ReceiptText} />
          <InfoCard label="Earnings" value={money(order.paymentStatus === 'Refunded' ? 0 : earnings)} helper="0% merchant processing fee" icon={Wallet} />
        </div>
      </section>

      <Panel
        title="Order progress"
        subtitle="Live operational lifecycle tracking for this fulfillment"
        action={<span className="rounded-md bg-slate-50 px-2.5 py-1 text-[10px] font-bold text-slate-500 dark:bg-gray-800 dark:text-gray-300">Standard 48-Hour SLA</span>}
      >
        <div className="px-5 py-6">
          {cancelled ? (
            <div className="flex items-center gap-3 rounded-xl bg-red-50 p-4 text-sm font-semibold text-red-600 dark:bg-red-900/20 dark:text-red-300">
              <X size={18} />
              This order has been cancelled.
            </div>
          ) : (
            <>
              <div className="hidden items-center md:flex">
                {progressSteps.map((step, index) => {
                  const done = activeStep >= index;
                  const pastStep = activeStep > index;
                  return (
                    <div key={step} className="flex flex-1 items-center">
                      <div className={`h-0.5 flex-1 ${index === 0 ? 'invisible' : done ? 'bg-[#d90445]' : 'bg-blue-100 dark:bg-gray-800'}`} />
                      <span className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full text-sm font-bold shadow-sm ${done ? 'bg-[#d90445] text-white' : 'bg-slate-50 text-slate-400 ring-1 ring-blue-100 dark:bg-gray-800 dark:ring-gray-700'}`}>
                        {done ? <Check size={18} /> : index + 1}
                      </span>
                      <div className={`h-0.5 flex-1 ${index === progressSteps.length - 1 ? 'invisible' : pastStep ? 'bg-[#d90445]' : 'bg-blue-100 dark:bg-gray-800'}`} />
                    </div>
                  );
                })}
              </div>
              <div className="grid gap-4 md:mt-3 md:grid-cols-4">
                {progressSteps.map((step, index) => {
                  const done = activeStep >= index;
                  const current = activeStep === index;
                  return (
                    <div key={step} className="flex items-center gap-3 md:block md:text-center">
                      <span className={`flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full text-sm font-bold md:hidden ${done ? 'bg-[#d90445] text-white' : 'bg-slate-50 text-slate-400 ring-1 ring-blue-100 dark:bg-gray-800 dark:ring-gray-700'}`}>
                        {done ? <Check size={17} /> : index + 1}
                      </span>
                      <div>
                        <p className={`text-sm font-bold ${done ? 'text-gray-950 dark:text-white' : 'text-slate-400'}`}>{step}</p>
                        <p className={`mt-0.5 text-[11px] font-medium ${current ? 'text-[#d90445]' : 'text-slate-400'}`}>{current ? 'Current step' : done ? 'Completed' : 'Waiting'}</p>
                        <p className="mt-0.5 text-[10px] text-slate-400">{index === 0 ? `${orderDate(order.date)}, ${orderTime}` : index === 1 ? 'Est. Today 2:00 PM' : index === 2 ? 'Courier assigned' : 'Est. Tomorrow'}</p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>
      </Panel>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="space-y-5">
          <Panel
            title="Purchased items"
            subtitle="Line items and physical manifest in this order."
            action={<span className="rounded-md bg-slate-50 px-2.5 py-1 text-[10px] font-bold text-slate-500 dark:bg-gray-800 dark:text-gray-300">{uniqueItems} Parcel</span>}
          >
            <div className="divide-y divide-blue-50 dark:divide-gray-800">
              {order.items.map((item) => (
                <div key={item.productId} className="flex flex-col gap-4 px-5 py-5 sm:flex-row sm:items-center">
                  <OrderProductImage item={item} products={products} className="h-16 w-20 rounded-xl" />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-bold leading-6 text-gray-950 dark:text-white">{item.name}</p>
                    <p className="mt-1 text-[11px] text-slate-500 dark:text-gray-400">SKU-8849-CL - Space Grey - Large (80x30cm)</p>
                    <div className="mt-2 flex flex-wrap items-center gap-2 text-[11px]">
                      <span className="text-slate-600 dark:text-gray-400">Qty: {item.quantity} x {money(item.unitPrice)}</span>
                      <span className="rounded-md bg-emerald-50 px-2 py-0.5 font-bold text-emerald-600 dark:bg-emerald-900/20">In Stock (48 units)</span>
                    </div>
                  </div>
                  <div className="text-left sm:text-right">
                    <p className="text-lg font-bold text-gray-950 dark:text-white">{money(item.unitPrice * item.quantity)}</p>
                    <p className="text-[11px] text-slate-500">{money(item.unitPrice)} / unit</p>
                  </div>
                </div>
              ))}
            </div>
            <div className="border-t border-blue-50 p-4 dark:border-gray-800">
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-slate-50 px-4 py-3 text-xs dark:bg-gray-950">
                <span className="inline-flex items-center gap-2 font-semibold text-slate-600 dark:text-gray-300"><Scale size={14} />Combined weight: 420 grams</span>
                <button type="button" className="inline-flex items-center gap-2 font-bold text-[#d90445] transition hover:text-[#fa3f5e]"><Gift size={14} />Add gift packaging</button>
              </div>
            </div>
          </Panel>

          <Panel
            title="Update order status"
            subtitle="Mutate fulfillment status, courier telemetry, and automated notifications."
            action={apiEnabled && <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1.5 text-[10px] font-bold text-emerald-600 dark:bg-emerald-900/20"><span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />Live updates</span>}
          >
            {editable ? (
              <div className="space-y-4 p-5">
                <div className="grid gap-4 md:grid-cols-2">
                  <Dropdown label="Order Status" value={selectedStatus} options={STATUS_OPTIONS} onChange={setSelectedStatus} />
                  <Dropdown label="Courier Partner" value={order.courier || 'Select courier'} options={COURIERS} onChange={(courier) => update({ courier })} />
                </div>
                <div>
                  <label htmlFor="order-tracking" className={labelCls}>Tracking AWB Number (Optional)</label>
                  <div className="relative">
                    <input id="order-tracking" value={order.trackingNumber} maxLength={80} onChange={(event) => update({ trackingNumber: event.target.value })} placeholder="BLUEDART-8823901" className={`${inputCls} pr-10`} />
                    <ReceiptText size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  </div>
                </div>
                <div className="flex items-center gap-3 rounded-xl border border-blue-100 p-4 dark:border-gray-800">
                  <Bell size={17} className="text-[#fa3f5e]" />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-bold text-gray-950 dark:text-white">Notify customer</p>
                    <p className="mt-1 text-[11px] text-slate-500 dark:text-gray-400">Send immediate automated status email and WhatsApp message to recipient.</p>
                  </div>
                  <Toggle checked={order.notifyCustomer} onChange={() => update({ notifyCustomer: !order.notifyCustomer })} label="Notify customer" />
                </div>
                <button type="button" disabled={updating || (apiEnabled ? !canSubmitStatus : !canShipOrder(order))} onClick={handleUpdateStatus} className="w-full rounded-xl bg-[#d90445] py-3 text-sm font-bold text-white shadow-lg shadow-pink-900/10 transition hover:bg-[#fa3f5e] disabled:cursor-not-allowed disabled:opacity-40">
                  <span className="inline-flex items-center justify-center gap-2"><RotateCw size={15} className={updating ? 'animate-spin' : ''} />{updating ? 'Updating...' : `Update to ${selectedStatus}`}</span>
                </button>
                <p className="text-center text-[11px] text-slate-400">{needsShippingInfo && !canSubmitStatus ? 'Enter courier and tracking number to mark as shipped.' : 'Status updates are sent to the order tracking API and synced with accounting.'}</p>
              </div>
            ) : (
              <div className="p-5">
                <div className="rounded-xl bg-slate-50 p-4 dark:bg-gray-950">
                  <div className="flex items-center gap-2 text-sm font-bold text-gray-950 dark:text-white">{order.status === 'Cancelled' ? <X size={17} /> : order.status === 'Delivered' ? <PackageCheck size={17} className="text-green-500" /> : <Truck size={17} className="text-[#fa3f5e]" />}<span role="status">{order.status === 'Shipped' ? 'Order shipped' : order.status === 'Delivered' ? 'Order delivered' : 'Order cancelled'}</span></div>
                  {order.courier && <p className="mt-2 break-words text-xs text-slate-500 dark:text-gray-400">{order.courier} - {order.trackingNumber}</p>}
                  <div className="mt-3"><PaymentBadge status={order.paymentStatus} /></div>
                  {apiEnabled && canAdvanceToDelivered && <button type="button" disabled={updating} onClick={() => setStatus('Delivered')} className="mt-4 w-full rounded-xl bg-[#d90445] py-3 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-40">{updating ? 'Updating...' : 'Mark as delivered'}</button>}
                </div>
              </div>
            )}
          </Panel>
        </div>

        <aside className="space-y-5">
          <Panel title="Customer Profile" icon={UserRound} action={<button type="button" className="text-[10px] font-bold text-[#d90445]">View CRM</button>}>
            <div className="p-5">
              <div className="flex items-center gap-3">
                <span className="flex h-12 w-12 items-center justify-center rounded-full bg-blue-50 text-sm font-bold text-gray-700 dark:bg-blue-900/20 dark:text-blue-200">{initials(order.customer).toUpperCase()}</span>
                <div>
                  <p className="text-sm font-bold text-gray-950 dark:text-white">{order.customer}</p>
                  <p className="text-xs text-slate-500 dark:text-gray-400">{customerEmail}</p>
                </div>
              </div>
              <div className="mt-4 space-y-2 text-xs">
                <div className="flex items-center gap-2 text-slate-600 dark:text-gray-400"><Phone size={13} /><span className="flex-1">Phone:</span><span className="font-semibold text-gray-950 dark:text-white">{customerPhone}</span></div>
                <div className="flex items-center gap-2 text-slate-600 dark:text-gray-400"><ShieldCheck size={13} /><span className="flex-1">Account status:</span><span className="font-semibold text-emerald-600">Verified ID</span></div>
                <div className="flex items-center gap-2 text-slate-600 dark:text-gray-400"><Wallet size={13} /><span className="flex-1">Total Spent:</span><span className="font-semibold text-gray-950 dark:text-white">{money(order.amount + 118)} (3 orders)</span></div>
              </div>
            </div>
          </Panel>

          <Panel title="Delivery address" icon={MapPin} action={<span className="rounded-md bg-emerald-50 px-2 py-1 text-[10px] font-bold text-emerald-600 dark:bg-emerald-900/20">Verified</span>}>
            <div className="space-y-4 p-5">
              <address className="not-italic text-sm leading-6 text-slate-600 dark:text-gray-400">
                <span className="font-bold text-gray-950 dark:text-white">{order.address.name}</span><br />
                {order.address.street}<br />
                {order.address.city}, {order.address.region} {order.address.postalCode}<br />
                {order.address.country}
              </address>
              <div className="rounded-xl border border-blue-100 bg-slate-50 p-3 text-xs leading-5 text-slate-600 dark:border-gray-800 dark:bg-gray-950 dark:text-gray-400">
                <span className="font-bold text-gray-950 dark:text-white">Delivery Instructions:</span> Please call upon arrival and leave package at main doorstep.
              </div>
            </div>
          </Panel>

          <Panel title="Payment" icon={CreditCard} action={<span className="rounded-md bg-emerald-50 px-2 py-1 text-[10px] font-bold text-emerald-600 dark:bg-emerald-900/20">Paid in Full</span>}>
            <div className="space-y-3 p-5 text-sm">
              <div className="flex items-center gap-2 text-slate-600 dark:text-gray-400"><CreditCard size={15} /><span className="flex-1">Payment received</span><span className="font-bold text-gray-950 dark:text-white">{money(order.amount)}</span></div>
              <div className="flex items-center gap-2 text-slate-600 dark:text-gray-400"><Coins size={15} /><span className="flex-1">B-Coins discount</span><span className="font-bold text-[#d90445]">-{money(order.coinsDiscount)}</span></div>
              <div className="flex items-center gap-2 text-slate-600 dark:text-gray-400"><Truck size={15} /><span className="flex-1">Delivery fee</span><span className="font-bold text-emerald-600">FREE</span></div>
              <div className="flex items-center gap-2 border-t border-blue-50 pt-3 text-[#d90445] dark:border-gray-800"><Wallet size={15} /><span className="flex-1 font-bold">Your earnings</span><span className="font-bold">{money(order.paymentStatus === 'Refunded' ? 0 : earnings)}</span></div>
              <div className="rounded-xl bg-pink-50 px-3 py-3 text-xs text-[#d90445] dark:bg-pink-900/20"><span className="font-bold">Payout Status:</span> Auto-settling in next batch (24h)</div>
            </div>
          </Panel>
        </aside>
      </div>
    </aside>
  );
}
