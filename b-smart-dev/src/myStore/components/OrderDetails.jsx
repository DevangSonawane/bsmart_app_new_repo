import React, { useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { X, MapPin, CreditCard, Coins, Wallet, Check, Truck, PackageCheck } from 'lucide-react';
import { Checkbox, Dropdown, inputCls, labelCls } from '../../components/productForm/ProductFormFields';
import { COURIERS, canShipOrder, shipOrder, updateOrderFulfillment } from '../../store/ordersSlice';
import { OrderProductImage, PaymentBadge } from './OrderUI';
import { money } from '../data/orderFilters';

function StepNumber({ number, done }) {
  return <span className={`w-5 h-5 rounded-full flex-shrink-0 inline-flex items-center justify-center text-[10px] font-bold ${done ? 'bg-[#fa3f5e] text-white' : 'bg-gray-100 dark:bg-gray-800 text-gray-500'}`}>{done ? <Check size={12} /> : number}</span>;
}

export default function OrderDetails({ order, closeTo }) {
  const dispatch = useDispatch();
  const products = useSelector((state) => state.products.items);
  const headingRef = useRef(null);
  useEffect(() => { headingRef.current?.focus({ preventScroll: true }); }, [order?.id]);
  if (!order) return (
    <aside className="rounded-2xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-6">
      <h2 ref={headingRef} tabIndex={-1} className="font-bold text-gray-900 dark:text-white">Order not found</h2>
      <Link to={closeTo} className="inline-block text-sm text-[#fa3f5e] mt-3">Back to orders</Link>
    </aside>
  );
  const editable = ['Pending', 'Processing'].includes(order.status);
  const update = (changes) => dispatch(updateOrderFulfillment({ id: order.id, ...changes }));
  const earnings = Math.max(0, order.amount - order.coinsDiscount);
  return (
    <aside aria-label="Order details" className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm overflow-hidden xl:sticky xl:top-6">
      <div className="px-5 pt-5 pb-4 border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center justify-between gap-3">
          <h2 ref={headingRef} tabIndex={-1} className="text-base font-bold text-gray-900 dark:text-white outline-none">Order details</h2>
          <Link to={closeTo} aria-label="Close order details" className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800"><X size={17} /></Link>
        </div>
        <div className="flex items-center justify-between gap-2 mt-1"><p className="text-xs text-gray-500">Order <span className="font-semibold text-[#fa3f5e]">#{order.id}</span></p><span className="text-xs text-gray-500 dark:text-gray-400">{order.status}</span></div>
      </div>
      <div className="p-5 space-y-5">
        <div className="divide-y divide-gray-100 dark:divide-gray-800">
          {order.items.map((item) => <div key={item.productId} className="flex items-start gap-3 py-3 first:pt-0">
            <OrderProductImage item={item} products={products} className="w-14 h-14" />
            <p className="flex-1 text-xs font-semibold text-gray-800 dark:text-gray-200 leading-5">{item.name}</p>
            <div className="text-right text-xs flex-shrink-0"><p className="font-semibold text-gray-800 dark:text-gray-200">{money(item.unitPrice * item.quantity)}</p><p className="text-gray-400 mt-1.5">Qty: {item.quantity}</p></div>
          </div>)}
        </div>
        <div className="flex gap-3 border-y border-gray-100 dark:border-gray-800 py-4">
          <MapPin size={16} className="text-gray-400 flex-shrink-0 mt-0.5" />
          <p className="text-xs font-medium text-gray-600 dark:text-gray-300 flex-1">Delivery address</p>
          <address className="text-xs not-italic text-gray-500 dark:text-gray-400 leading-5 max-w-[165px]"><span className="font-semibold text-gray-700 dark:text-gray-200">{order.address.name}</span><br />{order.address.street}<br />{order.address.city}, {order.address.region} {order.address.postalCode}<br />{order.address.country}</address>
        </div>
        <div className="space-y-3 text-xs">
          <div className="flex items-center gap-2 text-gray-500 dark:text-gray-400"><CreditCard size={15} /><span className="flex-1">{order.paymentStatus === 'Refunded' ? 'Payment refunded' : 'Payment received'}</span><span className="font-semibold text-gray-800 dark:text-gray-200">{money(order.amount)}</span></div>
          <div className="flex items-center gap-2 text-insta-purple"><Coins size={15} /><span className="flex-1">B-Coins discount</span><span className="font-semibold">−{money(order.coinsDiscount)}</span></div>
          <div className="flex items-center gap-2 text-[#fa3f5e] border-t border-gray-100 dark:border-gray-800 pt-3"><Wallet size={15} /><span className="flex-1 font-semibold">Your earnings</span><span className="font-bold">{money(order.paymentStatus === 'Refunded' ? 0 : earnings)}</span></div>
        </div>
        {editable ? <div>
          <h3 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Fulfill order</h3>
          <div className="border border-gray-100 dark:border-gray-800 rounded-xl divide-y divide-gray-100 dark:divide-gray-800">
            <div className="flex items-start gap-2.5 p-3"><StepNumber number={1} done={order.confirmed} /><div className="flex-1"><Checkbox checked={order.confirmed} onChange={(confirmed) => update({ confirmed })} label="Confirm items" /><p className="text-[11px] text-gray-400 mt-1">{order.confirmed ? 'All items confirmed' : 'Check the items in this order'}</p></div></div>
            <div className="flex items-start gap-2.5 p-3"><StepNumber number={2} done={order.packed} /><fieldset disabled={!order.confirmed} className="flex-1 disabled:opacity-50"><Checkbox checked={order.packed} onChange={(packed) => update({ packed })} label="Pack order" /><p className="text-[11px] text-gray-400 mt-1">{order.packed ? 'Order packed and ready' : 'Pack all confirmed items'}</p></fieldset></div>
            <div className="flex items-start gap-2.5 p-3"><StepNumber number={3} done={!!(order.courier && order.trackingNumber.trim())} /><div className="flex-1 min-w-0 space-y-3"><Dropdown label="Courier" value={order.courier || 'Select courier'} options={COURIERS} onChange={(courier) => update({ courier })} /><div><label htmlFor="order-tracking" className={labelCls}>Tracking number</label><input id="order-tracking" value={order.trackingNumber} maxLength={80} onChange={(event) => update({ trackingNumber: event.target.value })} placeholder="Enter tracking number" className={inputCls} /></div></div></div>
            <div className="flex items-center gap-2.5 p-3"><StepNumber number={4} done={order.notifyCustomer} /><div className="flex-1"><p className="text-xs font-semibold text-gray-700 dark:text-gray-200">Notify customer</p><p className="text-[11px] text-gray-400 mt-1">Send shipping confirmation</p></div><button type="button" role="switch" aria-checked={order.notifyCustomer} aria-label="Notify customer" onClick={() => update({ notifyCustomer: !order.notifyCustomer })} className={`w-9 h-5 rounded-full p-0.5 transition-colors ${order.notifyCustomer ? 'bg-[#fa3f5e]' : 'bg-gray-300 dark:bg-gray-700'}`}><span className={`block w-4 h-4 bg-white rounded-full shadow transition-transform ${order.notifyCustomer ? 'translate-x-4' : ''}`} /></button></div>
          </div>
          <button type="button" disabled={!canShipOrder(order)} onClick={() => dispatch(shipOrder(order.id))} className="w-full mt-4 py-3 rounded-xl text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange disabled:opacity-40 disabled:cursor-not-allowed">Mark as shipped</button>
          {!canShipOrder(order) && <p className="text-[11px] text-gray-400 mt-2">Confirm and pack the items, then enter the courier and tracking number.</p>}
        </div> : <div className="rounded-xl bg-gray-50 dark:bg-gray-800/60 p-4 space-y-3">
          <div className="flex items-center gap-2 text-sm font-semibold text-gray-800 dark:text-gray-200">{order.status === 'Cancelled' ? <X size={17} /> : order.status === 'Delivered' ? <PackageCheck size={17} className="text-green-500" /> : <Truck size={17} className="text-[#fa3f5e]" />}<span role="status">{order.status === 'Shipped' ? 'Order shipped' : order.status === 'Delivered' ? 'Order delivered' : 'Order cancelled'}</span></div>
          {order.courier && <p className="text-xs text-gray-500 dark:text-gray-400 break-words">{order.courier} · {order.trackingNumber}</p>}
          <PaymentBadge status={order.paymentStatus} />
        </div>}
      </div>
    </aside>
  );
}
