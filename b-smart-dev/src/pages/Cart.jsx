import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { Trash2, Minus, Plus, Heart, ArrowRight, ShoppingCart, Store, Truck, Package } from 'lucide-react';
import { removeItem, incrementQty, decrementQty, toggleSelection, selectAll, toggleSaved } from '../store/cartSlice';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';

const panel = 'bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm';
const primary = 'rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange';
const money = (value) => `₹${Number(value).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

function CartImage({ item }) {
  const [failed, setFailed] = useState(false);
  const src = item.images?.[0] || item.image;
  const Icon = CATEGORY_STYLE[item.category]?.icon || Package;
  return <div className="w-20 h-24 sm:w-32 sm:h-24 lg:w-36 lg:h-24 shrink-0 rounded-xl overflow-hidden bg-gray-50 dark:bg-gray-800 flex items-center justify-center">
    {src && !failed ? <img src={src} alt={item.name} onError={() => setFailed(true)} className="w-full h-full object-cover" /> : <Icon size={32} className="text-[#fa3f5e]" />}
  </div>;
}

export default function Cart() {
  const items = useSelector((state) => state.cart.items);
  const products = useSelector((state) => state.products.items);
  const user = useSelector((state) => state.auth.userObject);
  const ownerName = user?.name || user?.full_name || user?.username;
  const ownerAvatar = user?.profile_picture || user?.avatar;
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const active = items.filter((item) => !item.saved);
  const saved = items.filter((item) => item.saved);
  const selected = active.filter((item) => item.selected !== false);
  const allSelected = active.length > 0 && selected.length === active.length;
  const subtotal = selected.reduce((sum, item) => sum + item.price * item.qty, 0);
  const rewardCoins = Math.round(subtotal * 10);
  const groups = active.reduce((result, item) => {
    const name = item.storeName || (ownerName ? `${ownerName}'s Personal Store` : 'Your Personal Store');
    (result[name] ||= []).push(item);
    return result;
  }, {});

  const renderItem = (item) => {
    const product = products.find((entry) => entry.id === item.id);
    return <article key={item.id} className="flex flex-wrap sm:flex-nowrap items-center gap-3 p-2 border border-gray-100 dark:border-gray-800 rounded-xl">
      {!item.saved && <input type="checkbox" aria-label={`Select ${item.name}`} checked={item.selected !== false} onChange={() => dispatch(toggleSelection(item.id))} className="w-4 h-4 shrink-0 accent-[#fa3f5e] cursor-pointer" />}
      <CartImage item={{ ...product, ...item }} />
      <div className="flex-1 min-w-0">
        <Link to={`/market/product/${item.id}`} className="text-sm font-semibold text-gray-900 dark:text-white break-words hover:text-[#fa3f5e]">{item.name}</Link>
        <p className="text-sm font-semibold text-[#fa3f5e] mt-2">{money(item.price)}</p>
        <div className="inline-flex items-center border border-gray-200 dark:border-gray-700 rounded-lg mt-2">
          <button type="button" aria-label={`Decrease quantity of ${item.name}`} disabled={item.qty <= 1} onClick={() => dispatch(decrementQty(item.id))} className="p-2 text-[#fa3f5e] disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800"><Minus size={15} /></button>
          <span aria-label={`Quantity of ${item.name}`} className="min-w-7 text-center text-sm font-semibold text-gray-900 dark:text-white">{item.qty}</span>
          <button type="button" aria-label={`Increase quantity of ${item.name}`} onClick={() => dispatch(incrementQty(item.id))} className="p-2 text-[#fa3f5e] hover:bg-gray-50 dark:hover:bg-gray-800"><Plus size={15} /></button>
        </div>
      </div>
      <div className="w-full sm:w-auto flex sm:flex-col justify-end gap-4 sm:gap-4 sm:pl-1 sm:pr-2 shrink-0 text-xs text-gray-500 dark:text-gray-400">
        <button type="button" onClick={() => dispatch(toggleSaved(item.id))} className="flex items-center gap-2 hover:text-[#fa3f5e]"><Heart size={16} className={item.saved ? 'fill-[#fa3f5e] text-[#fa3f5e]' : ''} />{item.saved ? 'Move to cart' : 'Save for later'}</button>
        <button type="button" aria-label={`Remove ${item.name}`} onClick={() => dispatch(removeItem(item.id))} className="flex items-center gap-2 hover:text-[#fa3f5e]"><Trash2 size={16} />Remove</button>
      </div>
    </article>;
  };

  return <div className="min-h-screen bg-gray-50 dark:bg-black w-full max-w-[1280px] ml-auto px-4 md:px-6 pt-6 pb-24">
    {items.length === 0 ? <>
      <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">My Cart</h1>
      <div className="flex flex-col items-center py-24 text-center">
        <span className="w-20 h-20 rounded-full bg-pink-50 dark:bg-gray-900 flex items-center justify-center mb-5"><ShoppingCart size={30} className="text-[#fa3f5e]" /></span>
        <h2 className="text-lg font-bold text-gray-900 dark:text-white">Your cart is empty</h2>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-2 mb-6">Find something you love in the market.</p>
        <Link to="/market" className={`${primary} flex items-center gap-2 px-6 py-3`}>Browse the Market <ArrowRight size={16} /></Link>
      </div>
    </> : <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_320px] gap-6 items-start">
      <main className="min-w-0 space-y-4">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">My Cart</h1>
        <div className={`${panel} px-4 py-3 flex items-center justify-between gap-3`}>
          <label className="flex items-center gap-3 text-xs text-gray-600 dark:text-gray-300">
            <input type="checkbox" aria-label="Select all cart items" checked={allSelected} ref={(node) => { if (node) node.indeterminate = selected.length > 0 && !allSelected; }} onChange={() => dispatch(selectAll(!allSelected))} disabled={!active.length} className="w-4 h-4 accent-[#fa3f5e] cursor-pointer" />
            {selected.length} selected {selected.length === 1 ? 'item' : 'items'}
          </label>
          <button type="button" disabled={!active.length} onClick={() => dispatch(selectAll(true))} className="text-xs font-semibold text-[#fa3f5e] disabled:opacity-40">Select all</button>
        </div>
        {Object.entries(groups).map(([name, storeItems]) => <section key={name} aria-label={name} className={`${panel} p-2.5 space-y-2`}>
          <div className="flex items-center gap-3 px-1 pb-2">
            <span className="w-12 h-12 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0 overflow-hidden">{(storeItems[0].storeAvatar || ownerAvatar) ? <img src={storeItems[0].storeAvatar || ownerAvatar} alt={name} className="w-full h-full object-cover" /> : <Store size={24} className="text-[#fa3f5e]" />}</span>
            <div className="min-w-0"><h2 className="text-sm font-semibold text-gray-900 dark:text-white break-words">{name}</h2><p className="text-xs text-insta-purple mt-1">{storeItems[0].storeType || 'Personal Store'}</p></div>
          </div>
          {storeItems.map(renderItem)}
        </section>)}
        {active.length > 0 && <div className={`${panel} p-4 flex items-center gap-3 text-xs text-gray-600 dark:text-gray-300`}><span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center text-[#fa3f5e]"><Truck size={20} /></span>Delivery details at checkout</div>}
        {saved.length > 0 && <section aria-label="Saved for later" className={`${panel} p-3 space-y-3`}><h2 className="text-sm font-bold text-gray-900 dark:text-white px-1">Saved for later ({saved.length})</h2>{saved.map(renderItem)}</section>}
      </main>
      <aside aria-label="Order summary" className={`${panel} p-5 lg:sticky lg:top-6`}>
        <h2 className="text-base font-bold text-gray-900 dark:text-white mb-5">Order summary</h2>
        <dl className="space-y-4 text-sm text-gray-600 dark:text-gray-300 border-b border-gray-100 dark:border-gray-800 pb-5">
          <div className="flex justify-between gap-3"><dt>Subtotal</dt><dd>{money(subtotal)}</dd></div>
          <div className="flex justify-between gap-3"><dt>Delivery</dt><dd className="font-semibold text-[#fa3f5e]">Free</dd></div>

        </dl>
        <div className="flex justify-between items-center gap-3 py-5"><span className="text-sm font-semibold text-gray-900 dark:text-white">Total</span><span className="text-xl font-bold text-[#fa3f5e]">{money(subtotal)}</span></div>
        <div className="flex items-center gap-2.5 border-t border-gray-100 dark:border-gray-800 pt-3 pb-4 text-xs text-gray-500 dark:text-gray-400"><span className="w-7 h-7 shrink-0 rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white flex items-center justify-center text-lg font-bold">b</span><span>You will earn <span className="font-semibold text-[#fa3f5e]">{rewardCoins.toLocaleString('en-IN')} bCoins</span></span></div><button type="button" disabled={!selected.length} onClick={() => navigate('/checkout')} className={`${primary} w-full py-3 disabled:opacity-40 disabled:cursor-not-allowed`}>Proceed to Checkout</button>
        
      </aside>
    </div>}
  </div>;
}
