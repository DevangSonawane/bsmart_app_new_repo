import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { Trash2, Minus, Plus, Heart, ArrowRight, ShoppingCart, Store, Truck, Package, Loader2, AlertCircle, BadgeCheck, ShieldCheck, Lock } from 'lucide-react';
import {
  setCartItems, toggleSelection, selectAll, toggleSaved,
  incrementQty, decrementQty, removeItem, clearCart as clearCartItems,
} from '../store/cartSlice';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import cartService from '../services/cartService';
import influencerProductService from '../services/influencerProductService';

const panel = 'bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm';
const primary = 'rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange';
const money = (value) => `₹${Number(value).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

function CartImage({ item }) {
  const [failed, setFailed] = useState(false);
  const src = item.images?.[0] || item.image;
  const style = CATEGORY_STYLE[item.category];
  const Icon = style?.icon || Package;
  return <div className="relative w-20 h-24 sm:w-32 sm:h-24 lg:w-36 lg:h-24 shrink-0 rounded-xl overflow-hidden bg-gray-50 dark:bg-gray-800 flex items-center justify-center">
    {src && !failed ? <img src={src} alt={item.name} onError={() => setFailed(true)} className="w-full h-full object-cover" /> : <Icon size={32} className="text-[#fa3f5e]" />}
    {item.category && (
      <span className={`absolute top-1.5 left-1.5 rounded-md px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide bg-white/95 dark:bg-gray-900/95 ${style?.text || 'text-[#fa3f5e]'}`}>
        {item.category}
      </span>
    )}
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
  const [checkingOut, setCheckingOut] = useState(false);
  const [error, setError] = useState('');
  const [catalog, setCatalog] = useState({});

  useEffect(() => {
    let alive = true;
    influencerProductService.list()
      .then((list) => { if (alive) setCatalog(Object.fromEntries(list.map((product) => [String(product.id), product]))); })
      .catch(() => {});
    return () => { alive = false; };
  }, []);

  const proceedToCheckout = async () => {
    if (!selected.length || checkingOut) return;
    setCheckingOut(true);
    setError('');
    try {
      const cartItems = await cartService.syncItems(selected);
      dispatch(setCartItems(cartItems));
      navigate('/checkout');
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not prepare cart for checkout.');
    } finally {
      setCheckingOut(false);
    }
  };

  const active = items.filter((item) => !item.saved);
  const saved = items.filter((item) => item.saved);
  const selected = active.filter((item) => item.selected !== false);
  const allSelected = active.length > 0 && selected.length === active.length;
  const subtotal = selected.reduce((sum, item) => sum + item.price * item.qty, 0);
  const savings = selected.reduce((sum, item) => {
    const catalogProduct = catalog[String(item.id)];
    const mrp = Number(catalogProduct?.mrp || 0);
    return mrp > item.price ? sum + (mrp - item.price) * item.qty : sum;
  }, 0);
  const rewardCoins = Math.round(subtotal * 10);
  const groups = active.reduce((result, item) => {
    const name = item.storeName || (ownerName ? `${ownerName}'s Personal Store` : 'Your Personal Store');
    (result[name] ||= []).push(item);
    return result;
  }, {});

  const renderItem = (item) => {
    const product = products.find((entry) => entry.id === item.id);
    const catalogProduct = catalog[String(item.id)];
    const mrp = Number(catalogProduct?.mrp || 0);
    const hasDiscount = mrp > item.price;
    const discountPercent = hasDiscount ? Math.round((1 - item.price / mrp) * 100) : 0;
    const stockQuantity = catalogProduct?.stockQuantity;
    const lowStock = typeof stockQuantity === 'number' && stockQuantity > 0 && stockQuantity <= 5;
    return <article key={item.id} className="flex items-start gap-3 p-3 border border-gray-100 dark:border-gray-800 rounded-xl">
      {!item.saved && <input type="checkbox" aria-label={`Select ${item.name}`} checked={item.selected !== false} onChange={() => dispatch(toggleSelection(item.id))} className="w-4 h-4 mt-1 shrink-0 accent-[#fa3f5e] cursor-pointer" />}
      <CartImage item={{ ...product, ...item }} />
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            {catalogProduct?.vendor && (
              <p className="flex items-center gap-1 text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1">
                by {catalogProduct.vendor}
                {catalogProduct.seller?.is_verified && <><BadgeCheck size={12} className="text-[#fa3f5e]" /> · Verified Seller</>}
              </p>
            )}
            <Link to={`/market/product/${item.id}`} className="text-sm font-bold text-gray-900 dark:text-white break-words hover:text-[#fa3f5e]">{item.name}</Link>
          </div>
          <div className="text-right shrink-0">
            <p className="text-base font-bold text-gray-900 dark:text-white">{money(item.price)}</p>
            {hasDiscount && <p className="text-xs text-gray-400 line-through">{money(mrp)}</p>}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-1.5 mt-2">
          {item.variant?.size && <span className="rounded-md bg-gray-50 dark:bg-gray-800 px-2 py-0.5 text-[11px] font-semibold text-gray-600 dark:text-gray-300">Size: {item.variant.size}</span>}
          {item.variant?.color && (
            <span className="flex items-center gap-1.5 rounded-md bg-gray-50 dark:bg-gray-800 px-2 py-0.5 text-[11px] font-semibold text-gray-600 dark:text-gray-300">
              <span className="w-2.5 h-2.5 rounded-full border border-black/10 shrink-0" style={{ backgroundColor: item.variant.color }} /> Color: {item.variant.color}
            </span>
          )}
          {hasDiscount && <span className="rounded-md bg-green-50 dark:bg-green-900/20 px-2 py-0.5 text-[11px] font-bold text-green-600 dark:text-green-400">SAVE {discountPercent}%</span>}
          {lowStock && <span className="rounded-md bg-pink-50 dark:bg-pink-900/20 px-2 py-0.5 text-[11px] font-bold text-[#fa3f5e]">ONLY {stockQuantity} LEFT</span>}
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 mt-3">
          <div className="inline-flex items-center gap-2.5 rounded-full border border-gray-200 dark:border-gray-700 px-1.5 py-1">
            <button type="button" aria-label={`Decrease quantity of ${item.name}`} disabled={item.qty <= 1} onClick={() => dispatch(decrementQty(item.id))} className="flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 disabled:opacity-50 hover:bg-gray-200 dark:hover:bg-gray-700">
              <Minus size={13} />
            </button>
            <span aria-label={`Quantity of ${item.name}`} className="min-w-4 text-center text-sm font-semibold text-gray-900 dark:text-white">{item.qty}</span>
            <button type="button" aria-label={`Increase quantity of ${item.name}`} onClick={() => dispatch(incrementQty(item.id))} className="flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700">
              <Plus size={13} />
            </button>
          </div>
          <div className="flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400">
            <button type="button" onClick={() => dispatch(toggleSaved(item.id))} className="flex items-center gap-1.5 hover:text-[#fa3f5e]"><Heart size={14} className={item.saved ? 'fill-[#fa3f5e] text-[#fa3f5e]' : ''} />{item.saved ? 'Move to cart' : 'Save for later'}</button>
            <button type="button" aria-label={`Remove ${item.name}`} onClick={() => dispatch(removeItem(item.id))} className="flex items-center gap-1.5 hover:text-[#fa3f5e] disabled:opacity-40"><Trash2 size={14} />Remove</button>
          </div>
        </div>
      </div>
    </article>;
  };

  return <div className="min-h-screen bg-gray-50 dark:bg-black w-full max-w-[1280px] mx-auto px-4 md:px-6 pt-6 pb-24">
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
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">My Cart <span className="text-gray-400 dark:text-gray-500 font-semibold text-lg">({active.length} {active.length === 1 ? 'item' : 'items'})</span></h1>
          <span className="flex items-center gap-1.5 text-xs font-semibold text-gray-500 dark:text-gray-400"><Lock size={13} className="text-green-500" /> Secure checkout</span>
        </div>
        {error && <div className="flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300"><AlertCircle size={15} className="shrink-0" /> {error}</div>}
        <div className={`${panel} px-4 py-3 flex items-center justify-between gap-3`}>
          <label className="flex items-center gap-3 text-xs text-gray-600 dark:text-gray-300">
            <input type="checkbox" aria-label="Select all cart items" checked={allSelected} ref={(node) => { if (node) node.indeterminate = selected.length > 0 && !allSelected; }} onChange={() => dispatch(selectAll(!allSelected))} disabled={!active.length} className="w-4 h-4 accent-[#fa3f5e] cursor-pointer" />
            {selected.length} selected {selected.length === 1 ? 'item' : 'items'}
          </label>
          <div className="flex items-center gap-3">
            <button type="button" disabled={!active.length} onClick={() => dispatch(selectAll(true))} className="text-xs font-semibold text-[#fa3f5e] disabled:opacity-40">Select all</button>
            <button type="button" disabled={!items.length} onClick={() => dispatch(clearCartItems())} className="text-xs font-semibold text-red-500 disabled:opacity-40">Clear cart</button>
          </div>
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
          <div className="flex justify-between gap-3"><dt>Items subtotal ({selected.length})</dt><dd>{money(subtotal)}</dd></div>
          {savings > 0 && (
            <div className="flex justify-between gap-3 text-green-600 dark:text-green-400">
              <dt>You're saving</dt><dd className="font-semibold">-{money(savings)}</dd>
            </div>
          )}
          <div className="flex justify-between gap-3"><dt>Delivery</dt><dd className="font-semibold text-[#fa3f5e]">Free</dd></div>
        </dl>
        <div className="flex justify-between items-center gap-3 py-5"><span className="text-sm font-semibold text-gray-900 dark:text-white">Total</span><span className="text-xl font-bold text-[#fa3f5e]">{money(subtotal)}</span></div>
        <div className="flex items-center gap-2.5 border-t border-gray-100 dark:border-gray-800 pt-3 pb-4 text-xs text-gray-500 dark:text-gray-400"><span className="w-7 h-7 shrink-0 rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white flex items-center justify-center text-lg font-bold">b</span><span>You will earn <span className="font-semibold text-[#fa3f5e]">{rewardCoins.toLocaleString('en-IN')} bCoins</span></span></div>
        <button type="button" disabled={!selected.length || checkingOut} onClick={proceedToCheckout} className="w-full py-3.5 rounded-full text-sm font-bold text-white bg-gradient-to-r from-[#9f1239] to-[#fa3f5e] disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2">{checkingOut ? <span className="inline-flex items-center justify-center gap-2"><Loader2 size={16} className="animate-spin" />Checking cart...</span> : <>Proceed to Checkout <ArrowRight size={16} /></>}</button>
        <div className="mt-4 flex items-start gap-2 text-[11px] leading-5 text-gray-400 dark:text-gray-500">
          <ShieldCheck size={14} className="shrink-0 mt-0.5 text-green-500" />
          Secure payments via Razorpay — UPI, cards, netbanking &amp; wallets.
        </div>
      </aside>
    </div>}
  </div>;
}
