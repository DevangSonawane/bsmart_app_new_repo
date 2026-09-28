import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { MapPin, Plus, Check, CreditCard, ChevronRight, Lock, CheckCircle2, X, Home, Briefcase, Wallet, ShieldCheck, Package } from 'lucide-react';
import { checkoutSelected } from '../store/cartSlice';
import { placeOrder } from '../store/ordersSlice';
import { inputCls } from '../components/productForm/ProductFormFields';

const panel = 'bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-sm';
const primary = 'rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange focus:outline-none focus-visible:ring-2 focus-visible:ring-insta-pink focus-visible:ring-offset-2 disabled:opacity-40 disabled:cursor-not-allowed';
const money = (value) => `₹${Number(value).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const initialAddresses = [
  { id: 'home', label: 'Home', address: '123 Commerce St, Suite 400', city: 'San Francisco', state: 'CA', zip: '94105' },
  { id: 'work', label: 'Work', address: '460 Harbor Avenue', city: 'San Diego', state: 'CA', zip: '92101' },
];
const blankAddress = { label: '', address: '', city: '', state: '', zip: '' };

function ProductImage({ item }) {
  const [failed, setFailed] = useState(false);
  const image = item.images?.[0] || item.image;
  return <div className="w-14 h-14 shrink-0 rounded-lg bg-gray-50 dark:bg-gray-800 overflow-hidden flex items-center justify-center">{image && !failed ? <img src={image} alt={item.name} onError={() => setFailed(true)} className="w-full h-full object-cover" /> : <Package size={24} className="text-[#fa3f5e]" />}</div>;
}

function AddressDrawer({ addresses, selected, onClose, onSelect, onAdd }) {

  const [pending, setPending] = useState(selected);
  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState(blankAddress);

  const submit = (event) => {
    event.preventDefault();
    if (Object.values(form).some((value) => !value.trim())) return;
    const id = `address-${Date.now()}`;
    onAdd({ ...form, id });
    setPending(id);
    setAdding(false);
    setForm(blankAddress);
  };
  return <aside aria-labelledby="address-title" className="min-w-0 w-full lg:sticky lg:top-0 h-[min(720px,90dvh)] lg:h-[calc(100dvh-32px)] bg-white dark:bg-gray-900 text-gray-900 dark:text-white border-l border-gray-100 dark:border-gray-800 shadow-sm rounded-xl">
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-4 border-b border-gray-100 dark:border-gray-800 px-5 py-5"><button type="button" onClick={onClose} aria-label="Close address selector" className="p-1 text-gray-500"><X size={19} /></button><h2 id="address-title" className="text-sm font-semibold">Select address</h2></div>
      <div className="flex-1 overflow-y-auto p-5 space-y-4">
        <p className="text-xs text-gray-500 dark:text-gray-400">Saved addresses</p>
        {addresses.map((address) => <label key={address.id} className={`flex items-center gap-3 rounded-xl border p-4 cursor-pointer ${pending === address.id ? 'border-[#fa3f5e] bg-pink-50/40 dark:bg-pink-900/10' : 'border-gray-200 dark:border-gray-700'}`}>
          <input type="radio" name="delivery-address" value={address.id} checked={pending === address.id} onChange={() => setPending(address.id)} className="accent-[#fa3f5e] w-4 h-4 shrink-0" />
          <div className="min-w-0"><p className="flex items-center gap-2 text-sm font-semibold"><span className="text-[#fa3f5e]">{address.label === 'Work' ? <Briefcase size={18} /> : <Home size={18} />}</span>{address.label}{address.id === 'home' && <span className="rounded bg-purple-50 dark:bg-purple-900/20 px-2 py-1 text-[10px] text-insta-purple">Default</span>}</p><p className="text-xs leading-6 text-gray-500 dark:text-gray-400 mt-2 break-words">{address.address}<br />{address.city}, {address.state} {address.zip}</p></div>
        </label>)}
        <button type="button" onClick={() => setAdding(!adding)} aria-expanded={adding} className="w-full flex items-center justify-center gap-2 border border-dashed border-[#fa3f5e]/40 rounded-lg py-4 text-xs font-semibold text-[#fa3f5e]"><Plus size={18} />{adding ? 'Cancel new address' : 'Add new address'}</button>
        {adding && <form onSubmit={submit} className="space-y-3">{[['label', 'Address label'], ['address', 'Street address'], ['city', 'City'], ['state', 'State'], ['zip', 'Postal code']].map(([key, label]) => <label key={key} className="block text-xs text-gray-500 dark:text-gray-400">{label}<input required maxLength={150} name={key} value={form[key]} onChange={(event) => setForm({ ...form, [key]: event.target.value })} className={`${inputCls} mt-1`} /></label>)}<button className={`${primary} w-full py-3`}>Save address</button></form>}
      </div>
      <div className="p-5 border-t border-gray-100 dark:border-gray-800"><button type="button" onClick={() => onSelect(pending)} className={`${primary} w-full py-3`}>Use this address</button></div>
    </div>
  </aside>;
}

export default function Checkout() {
  const items = useSelector((state) => state.cart.items).filter((item) => !item.saved && item.selected !== false);
  const products = useSelector((state) => state.products.items);
  const user = useSelector((state) => state.auth.userObject);
  const balance = Math.max(0, Number(useSelector((state) => state.wallet?.balance) || 0));
  const dispatch = useDispatch();
  const [step, setStep] = useState('Details');
  const [addresses, setAddresses] = useState(initialAddresses);
  const [selectedAddress, setSelectedAddress] = useState('home');
  const [addressOpen, setAddressOpen] = useState(true);
  const [useCoins, setUseCoins] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState('saved');
  const [sameBilling, setSameBilling] = useState(true);
  const [billing, setBilling] = useState('');
  const [card, setCard] = useState({ number: '', expiry: '', cvv: '' });
  const [placed, setPlaced] = useState(false);
  const [checkoutError, setCheckoutError] = useState('');
  const address = addresses.find((entry) => entry.id === selectedAddress);
  const subtotal = items.reduce((sum, item) => sum + item.price * item.qty, 0);
  // Preview-only redemption rate. No wallet mutation or payment request is made.
  const discount = useCoins || paymentMethod === 'coins' ? Math.min(balance, subtotal) : 0;
  const total = Math.max(0, subtotal - discount);
  const payment = step === 'Payment';

  const submit = (event) => {
    event.preventDefault();
    if (!sameBilling && !billing.trim()) return;
    if (!payment) { setStep('Payment'); return; }
    if (paymentMethod === 'coins' && balance < subtotal) return;
    const buyerId = user?._id || user?.id;
    if (!buyerId) { setCheckoutError('Please sign in again to place your order.'); return; }
    const customer = user.name || user.full_name || user.username || 'Customer';
    dispatch(placeOrder({
      buyerId: String(buyerId), customer,
      productId: items[0].id, product: items[0].name,
      qty: items.reduce((sum, item) => sum + item.qty, 0),
      items: items.map((item) => ({ productId: item.id, name: item.name, quantity: item.qty, unitPrice: item.price })),
      amount: subtotal, coinsDiscount: discount, paymentStatus: 'Paid',
      address: { name: customer, street: address.address, city: address.city, region: address.state, postalCode: address.zip, country: 'India' },
    }));
    dispatch(checkoutSelected());
    setCard({ number: '', expiry: '', cvv: '' });
    setPlaced(true);
  };

  const itemList = <div className="divide-y divide-gray-100 dark:divide-gray-800">{items.map((item) => <div key={item.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0"><ProductImage item={{ ...products.find((product) => product.id === item.id), ...item }} /><div className="min-w-0 flex-1"><p className="text-xs font-medium text-gray-900 dark:text-white break-words">{item.name}</p><p className="text-xs text-gray-400 mt-1">Qty: {item.qty}</p></div><span className="text-xs font-semibold text-gray-900 dark:text-white shrink-0">{money(item.price * item.qty)}</span></div>)}</div>;
  const billingControl = <><label className="flex items-center gap-3 text-xs text-gray-600 dark:text-gray-300"><input type="checkbox" checked={sameBilling} onChange={(event) => setSameBilling(event.target.checked)} className="accent-[#fa3f5e] w-4 h-4" />{payment ? 'Use delivery address as billing address' : 'Billing address is the same as delivery address'}</label>{!sameBilling && <label className="block text-xs text-gray-500 mt-3">Billing address<textarea required value={billing} onChange={(event) => setBilling(event.target.value)} className={`${inputCls} mt-2`} /></label>}</>;

  if (placed) return <div className="min-h-screen flex flex-col items-center justify-center gap-4 px-4 bg-gray-50 dark:bg-black text-center"><CheckCircle2 size={48} className="text-[#fa3f5e]" /><h1 className="text-xl font-bold text-gray-900 dark:text-white">Order placed!</h1><p className="text-sm text-gray-500">This is a mock checkout. No payment was processed or bCoins deducted.</p><div className="flex flex-wrap justify-center gap-3"><Link to="/market/my-orders" className={`${primary} px-5 py-3`}>View My Orders</Link><Link to="/market" className="px-5 py-3 rounded-lg border border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-700 dark:text-gray-300">Back to Market</Link></div></div>;
  if (!items.length) return <div className="min-h-screen flex flex-col items-center justify-center gap-3 bg-gray-50 dark:bg-black"><p className="text-gray-500">Your cart is empty.</p><Link to="/cart" className="text-[#fa3f5e]">Back to cart</Link></div>;

  return <div className={`min-h-screen bg-gray-50 dark:bg-black w-full max-w-[1300px] ml-auto px-4 md:px-6 pt-4 pb-12 text-gray-900 dark:text-white grid gap-4 items-start ${addressOpen && !payment ? 'lg:grid-cols-[minmax(0,1fr)_280px]' : 'grid-cols-1'}`}><div className="min-w-0">
    <h1 className={payment ? 'sr-only' : 'text-xl font-bold mb-4'}>Checkout</h1>
    <nav aria-label="Checkout progress" className={payment ? 'w-full md:w-[64%] pt-2 mb-8' : 'max-w-[300px] mb-5'}><ol className="flex">{['Cart', 'Details', 'Payment'].map((label, index) => {
      const complete = index === 0 || (index === 1 && payment);
      const current = label === step;
      const content = <><span className={`relative z-10 w-6 h-6 rounded-full flex items-center justify-center text-xs font-semibold ${complete || current ? 'bg-[#fa3f5e] text-white' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 text-gray-400'}`}>{complete ? <Check size={14} /> : index + 1}</span><span className={`mt-2 text-[11px] ${current ? 'font-semibold' : 'text-gray-400'}`}>{label}</span></>;
      return <li key={label} className="relative flex-1">{index < 2 && <span aria-hidden="true" className={`absolute top-3 left-1/2 w-full h-px ${complete && (index === 0 || payment) ? 'bg-[#fa3f5e]' : 'bg-gray-200 dark:bg-gray-700'}`} />}{label === 'Cart' ? <Link to="/cart" className="relative flex flex-col items-center">{content}</Link> : <button type="button" aria-current={current ? 'step' : undefined} onClick={() => setStep(label)} className="relative w-full flex flex-col items-center">{content}</button>}</li>;
    })}</ol></nav>
    <form onSubmit={submit} className={`grid grid-cols-1 gap-4 items-start ${payment ? 'md:grid-cols-[minmax(0,1.8fr)_minmax(0,1fr)] md:gap-6' : 'md:grid-cols-[minmax(0,2fr)_minmax(190px,1fr)]'}`}>
      <main className="min-w-0 space-y-3">
        {!payment ? <>
          <section className={`${panel} p-3 flex items-start gap-3`}><span className="p-2 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]"><MapPin size={20} /></span><div className="flex-1 min-w-0"><h2 className="text-sm font-semibold">Delivery address</h2><p className="text-xs font-semibold mt-2">{address.label}</p><p className="text-xs text-gray-500 dark:text-gray-400 mt-1 break-words">{address.address}, {address.city}, {address.state} {address.zip}</p></div><button type="button" onClick={() => setAddressOpen(true)} className="flex items-center gap-1 text-xs text-[#fa3f5e] py-1">Change <ChevronRight size={14} /></button></section>
          <section className={`${panel} p-3`}><h2 className="text-sm font-semibold mb-4">Order summary</h2>{itemList}</section>
          <section className={`${panel} p-3 flex items-center gap-3`}><span className="w-7 h-7 rounded-full bg-[#fa3f5e] text-white font-bold text-xl text-center">b</span><div className="flex-1"><h2 className="text-xs font-semibold">Use bCoins</h2><p className="text-[11px] text-gray-400 mt-1">{balance.toLocaleString('en-IN')} available</p></div><button type="button" role="switch" aria-checked={useCoins} aria-label="Use bCoins" disabled={!balance} onClick={() => setUseCoins(!useCoins)} className={`w-10 h-6 rounded-full p-0.5 disabled:opacity-40 ${useCoins ? 'bg-[#fa3f5e]' : 'bg-gray-300 dark:bg-gray-700'}`}><span className={`block h-5 w-5 rounded-full bg-white shadow transition-transform ${useCoins ? 'translate-x-4' : ''}`} /></button></section>
          <section className={`${panel} p-3`}><button type="button" onClick={() => setStep('Payment')} className="flex items-center gap-3 w-full text-xs pb-4 mb-4 border-b border-gray-100 dark:border-gray-800"><CreditCard size={20} className="text-[#fa3f5e]" /><span className="flex-1 text-left">{paymentMethod === 'saved' ? 'Visa •••• 4821' : paymentMethod === 'new' ? 'New card' : paymentMethod === 'wallet' ? 'Digital wallet' : 'Pay with bCoins'}</span><ChevronRight size={16} /></button>{billingControl}</section>
        </> : <>
          <h2 className="text-lg font-semibold">Choose payment method</h2>
          <div role="radiogroup" aria-label="Payment method" className="space-y-3">{[['saved', 'Visa •••• 4821', CreditCard], ['new', 'Add new card', CreditCard], ['wallet', 'Digital wallet', Wallet], ['coins', 'Pay with bCoins', Wallet]].map(([id, label, Icon]) => <div key={id}>
            <label className={`${panel} flex items-center gap-3 px-3 py-2.5 min-h-[64px] cursor-pointer ${paymentMethod === id ? '!border-[#fa3f5e]' : ''}`}><input type="radio" name="payment-method" value={id} checked={paymentMethod === id} onChange={() => setPaymentMethod(id)} className="w-4 h-4 shrink-0 accent-[#fa3f5e]" /><span className={`w-12 h-10 shrink-0 rounded-lg border border-gray-100 dark:border-gray-800 flex items-center justify-center ${id === 'coins' ? 'text-insta-purple' : 'text-gray-700 dark:text-gray-300'}`}>{id === 'saved' ? <span className="italic font-bold text-xs text-blue-600 dark:text-blue-400">VISA</span> : id === 'coins' ? <span className="w-8 h-8 rounded-full border border-insta-purple flex items-center justify-center text-2xl font-bold">b</span> : React.createElement(Icon, { size: 23 })}</span><span className="flex-1 min-w-0 text-sm font-semibold">{label}{id === 'saved' && <span className="block text-xs font-normal text-gray-400 mt-1">Expires 08/29</span>}</span>{paymentMethod === id ? <span className="rounded bg-[#fa3f5e] text-white px-2 py-1 text-[10px]">Selected</span> : <ChevronRight size={17} className="text-gray-400" />}</label>
            {id === 'new' && paymentMethod === id && <div className={`${panel} p-3 mt-2 grid grid-cols-2 gap-3`}>{[['number', 'Card number', '[0-9 ]{13,23}', 23], ['expiry', 'Expiry (MM/YY)', '(0[1-9]|1[0-2])/[0-9]{2}', 5], ['cvv', 'CVV', '[0-9]{3,4}', 4]].map(([key, title, pattern, maxLength]) => <label key={key} className={`text-xs text-gray-500 ${key === 'number' ? 'col-span-2' : ''}`}>{title}<input required aria-label={title} inputMode={key === 'expiry' ? 'text' : 'numeric'} type={key === 'cvv' ? 'password' : 'text'} autoComplete="off" pattern={pattern} maxLength={maxLength} value={card[key]} onChange={(event) => setCard({ ...card, [key]: event.target.value })} className={`${inputCls} mt-1`} /></label>)}</div>}
            {id === 'wallet' && paymentMethod === id && <p className="px-4 pt-2 text-xs text-gray-400">Digital wallet selected for this payment preview.</p>}
            {id === 'coins' && paymentMethod === id && <p className="px-4 pt-2 text-xs text-gray-400">{balance.toLocaleString('en-IN')} bCoins available{balance < subtotal ? ' — insufficient balance for this order.' : ''}</p>}
          </div>)}</div>
          <section className={`${panel} p-3`}>{billingControl}</section>
          <div className="flex items-start gap-3 px-2 py-2"><ShieldCheck size={30} className="text-[#fa3f5e] shrink-0" /><div><h3 className="text-xs font-semibold">Secure payment</h3><p className="text-xs text-gray-400 mt-1">Payment preview only. No real charge is made.</p></div></div>
        </>}
      </main>
      <aside className={`${panel} min-w-0 lg:sticky lg:top-4 ${payment ? 'p-5' : 'p-3'}`} aria-label="Payment summary">
        {payment && <><h2 className="text-sm font-semibold mb-5">Order summary</h2><div className="pb-5 mb-5 border-b border-gray-100 dark:border-gray-800">{itemList}</div></>}
        <dl className="space-y-4 text-xs text-gray-500 dark:text-gray-400 pb-5 border-b border-gray-100 dark:border-gray-800"><div className="flex justify-between gap-3"><dt>Subtotal</dt><dd>{money(subtotal)}</dd></div>{!payment && <div className="flex justify-between gap-3"><dt>Delivery</dt><dd className="text-[#fa3f5e] font-semibold">Free</dd></div>}<div className="flex justify-between gap-3 text-insta-purple"><dt>bCoins discount</dt><dd>−{money(discount)}</dd></div></dl>
        <div className="flex justify-between items-center py-3 gap-3"><span className="text-sm font-semibold">{payment ? 'Amount due' : 'Total'}</span><strong className="text-xl text-[#fa3f5e]">{money(total)}</strong></div>
        {checkoutError && <p role="alert" className="text-xs text-red-500">{checkoutError}</p>}
        <button type="submit" disabled={payment && paymentMethod === 'coins' && balance < subtotal} className={`${primary} w-full py-3 flex items-center justify-center gap-2`}>{payment ? <><Lock size={16} />Pay {money(total)}</> : 'Place order'}</button>
        {!payment && <p className="text-[10px] text-gray-400 text-center mt-3"><Lock size={11} className="inline mr-1" />Secure checkout<br />Review payment in the next step</p>}
      </aside>
    </form>
    {!payment && <p className="text-[11px] text-gray-400 mt-5">Demo checkout with sample addresses and card. bCoins preview: 1 coin = ₹1. No real payment or wallet debit.</p>}
    </div>{addressOpen && !payment && <AddressDrawer addresses={addresses} selected={selectedAddress} onClose={() => setAddressOpen(false)} onSelect={(id) => { setSelectedAddress(id); setAddressOpen(false); }} onAdd={(entry) => setAddresses((current) => [...current, entry])} />}
  </div>;
}
