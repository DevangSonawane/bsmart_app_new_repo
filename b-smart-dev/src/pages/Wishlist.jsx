import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  ArrowLeft, Heart, Star, Eye, ShoppingCart, Trash2, RefreshCw,
  Search, Package, Loader2, ShoppingBag, Sparkles, ChevronRight,
} from 'lucide-react';
import { addItem } from '../store/cartSlice';
import { toggleWishlistItem } from '../store/wishlistSlice';
import { useWishlist } from '../hooks/useMarketplaceWishlist';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import { ServiceCard } from './Market';

const primaryBtn = 'text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange';
const money = (v) => `₹${Number(v || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

function ProductImage({ product }) {
  const [failed, setFailed] = useState(false);
  const src = !failed ? (product.images?.[0] || product.image) : null;
  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };
  if (src) {
    return (
      <div className="relative w-full h-full bg-gray-50 dark:bg-gray-800">
        <img src={src} alt={product.name} onError={() => setFailed(true)} className="w-full h-full object-cover" loading="lazy" />
      </div>
    );
  }
  return (
    <div className={`relative w-full h-full flex items-center justify-center ${bg}`}>
      <Icon size={48} className={`${text} opacity-70`} />
    </div>
  );
}

function WishlistProductCard({ product, mutating, onRemove, onAddToCart }) {
  const { text } = CATEGORY_STYLE[product.category] || { text: 'text-[#fa3f5e]' };
  return (
    <article className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden flex flex-col">
      <div className="relative aspect-[4/3] overflow-hidden">
        <Link to={`/market/product/${product.id}`} aria-label={`View ${product.name}`} className="absolute inset-0">
          <ProductImage product={product} />
        </Link>
        <span className="absolute top-3 left-3 px-2 py-0.5 rounded-md bg-white/90 dark:bg-black/60 text-[10px] font-bold tracking-wide text-gray-700 dark:text-gray-200 uppercase">
          Wishlist
        </span>
        <button
          type="button"
          aria-label={`Remove ${product.name} from wishlist`}
          disabled={mutating}
          onClick={onRemove}
          className="absolute top-3 right-3 w-7 h-7 rounded-full bg-white dark:bg-gray-800 shadow flex items-center justify-center hover:scale-105 transition-transform disabled:opacity-60"
        >
          {mutating ? <Loader2 size={14} className="animate-spin text-[#fa3f5e]" /> : <Heart size={14} className="fill-[#fa3f5e] text-[#fa3f5e]" />}
        </button>
      </div>

      <div className="p-4 flex flex-col flex-1">
        <p className={`text-[11px] font-bold uppercase tracking-wide mb-1 ${text}`}>{product.category}</p>
        <Link to={`/market/product/${product.id}`}>
          <h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1.5 truncate hover:text-[#fa3f5e] transition-colors" title={product.name}>
            {product.name}
          </h3>
        </Link>
        {product.vendor ? <p className="text-xs text-gray-400 dark:text-gray-500 mb-2 truncate">by {product.vendor}</p> : null}
        <div className="flex items-center gap-1 text-xs text-gray-400 dark:text-gray-500 mb-2.5">
          <Star size={12} className="fill-amber-400 text-amber-400" />
          <span>{product.rating ? product.rating : 'New'}</span>
          {product.reviews ? <span className="ml-1">({product.reviews})</span> : null}
          {product.views ? (<><span className="mx-1">·</span><Eye size={12} /><span>{product.views}</span></>) : null}
        </div>
        <p className="font-bold text-[#fa3f5e] mb-1">
          {money(product.price)} <span className="text-gray-400 dark:text-gray-500 text-xs font-normal">INR</span>
        </p>
        {product.originalPrice && Number(product.originalPrice) > Number(product.price) ? (
          <p className="text-xs text-gray-400 line-through mb-3">{money(product.originalPrice)}</p>
        ) : <div className="mb-3" />}
        <div className="flex gap-2 mt-auto">
          <button
            onClick={onAddToCart}
            className={`flex-1 py-1.5 rounded-lg text-xs font-bold flex items-center justify-center gap-1 ${primaryBtn}`}
          >
            <ShoppingCart size={13} /> Add to Cart
          </button>
          <Link
            to={`/market/product/${product.id}`}
            className="flex-1 py-1.5 rounded-lg text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 text-center hover:border-[#fa3f5e] hover:text-[#fa3f5e] transition-colors"
          >
            View Details
          </Link>
        </div>
      </div>
    </article>
  );
}

function SkeletonCard() {
  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 overflow-hidden animate-pulse">
      <div className="aspect-[4/3] bg-gray-100 dark:bg-gray-800" />
      <div className="p-4 space-y-2">
        <div className="h-3 w-1/3 bg-gray-100 dark:bg-gray-800 rounded" />
        <div className="h-4 w-3/4 bg-gray-100 dark:bg-gray-800 rounded" />
        <div className="h-4 w-1/2 bg-gray-100 dark:bg-gray-800 rounded" />
        <div className="flex gap-2 pt-1"><div className="h-7 flex-1 bg-gray-100 dark:bg-gray-800 rounded-lg" /><div className="h-7 flex-1 bg-gray-100 dark:bg-gray-800 rounded-lg" /></div>
      </div>
    </div>
  );
}

const SORTS = [
  { id: 'newest', label: 'Newest first' },
  { id: 'price-asc', label: 'Price: Low to High' },
  { id: 'price-desc', label: 'Price: High to Low' },
  { id: 'rating', label: 'Top rated' },
  { id: 'name', label: 'Name A–Z' },
];

export default function Wishlist() {
  const dispatch = useDispatch();
  const { items, count, loading, error, mutatingId, clearing, remove, clear, refresh } = useWishlist();
  const services = useSelector((state) => state.services.items);
  const user = useSelector((state) => state.auth.userObject);
  const userId = user?._id || user?.id;
  const localRaw = useSelector((state) => (userId ? state.wishlist.byUser[String(userId)] : undefined));
  const localSaved = useMemo(() => localRaw || [], [localRaw]);
  const savedServices = useMemo(() => localSaved
    .filter((i) => i.type === 'service')
    .map((i) => services.find((s) => String(s.id) === i.id && s.status === 'Published' && s.visible))
    .filter(Boolean), [localSaved, services]);
  const untoggleLocal = (type, id) => {
    if (userId) dispatch(toggleWishlistItem({ userId: String(userId), type, id }));
  };

  const [query, setQuery] = useState('');
  const [sort, setSort] = useState('newest');
  const [confirmClear, setConfirmClear] = useState(false);
  const [notice, setNotice] = useState(null);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    let list = q
      ? items.filter((p) => [p.name, p.category, p.vendor, p.description].some((v) => String(v ?? '').toLowerCase().includes(q)))
      : [...items];
    switch (sort) {
      case 'price-asc': list.sort((a, b) => a.price - b.price); break;
      case 'price-desc': list.sort((a, b) => b.price - a.price); break;
      case 'rating': list.sort((a, b) => (b.rating || 0) - (a.rating || 0)); break;
      case 'name': list.sort((a, b) => String(a.name).localeCompare(String(b.name))); break;
      default: break; // backend already returns newest-added first
    }
    return list;
  }, [items, query, sort]);

  const totalValue = useMemo(() => items.reduce((s, p) => s + (Number(p.price) || 0), 0), [items]);
  const avgRating = useMemo(() => {
    const rated = items.filter((p) => p.rating > 0);
    if (!rated.length) return 0;
    return rated.reduce((s, p) => s + p.rating, 0) / rated.length;
  }, [items]);

  const handleAddToCart = (product) => {
    dispatch(addItem({
      id: product.rawId ?? product.id,
      name: product.name,
      subtitle: product.dimensions || product.description?.slice(0, 60),
      brand: product.vendor,
      price: Number(product.price) || 0,
      category: product.category,
      images: product.images,
      image: product.image,
    }));
    setNotice(`${product.name} moved to cart`);
    setTimeout(() => setNotice(null), 2200);
  };

  const handleMoveAll = () => {
    filtered.forEach(handleAddToCartSilent);
    setNotice(`${filtered.length} item${filtered.length === 1 ? '' : 's'} moved to cart`);
    setTimeout(() => setNotice(null), 2200);
  };
  const handleAddToCartSilent = (product) => {
    dispatch(addItem({
      id: product.rawId ?? product.id,
      name: product.name,
      subtitle: product.dimensions || product.description?.slice(0, 60),
      brand: product.vendor,
      price: Number(product.price) || 0,
      category: product.category,
      images: product.images,
      image: product.image,
    }));
  };

  const handleClear = async () => {
    if (!confirmClear) {
      setConfirmClear(true);
      setTimeout(() => setConfirmClear(false), 4000);
      return;
    }
    setConfirmClear(false);
    await clear();
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      {/* Breadcrumb */}
      <Link to="/market" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e] mb-5">
        <ArrowLeft size={16} /> Back to Marketplace
      </Link>

      {/* Header */}
      <div className="flex flex-wrap items-end justify-between gap-3 mb-1">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center gap-2">
            Wishlist
            <span className="text-xs font-bold px-2.5 py-1 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">
              {loading ? '…' : `${count} saved`}
            </span>
          </h1>
          <p className="text-xs text-gray-400 dark:text-gray-500 mt-1.5 flex items-center gap-1">
            <Sparkles size={12} /> Synced to your account · newest-added first
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => refresh()}
            disabled={loading}
            className="flex items-center gap-1.5 px-3 h-10 rounded-full border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:border-[#fa3f5e] hover:text-[#fa3f5e] transition-colors disabled:opacity-50"
          >
            <RefreshCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh
          </button>
          {count > 0 && (
            <>
              <button
                onClick={handleMoveAll}
                className={`flex items-center gap-1.5 px-4 h-10 rounded-full text-sm font-bold ${primaryBtn}`}
              >
                <ShoppingCart size={15} /> Move all to cart
              </button>
              <button
                onClick={handleClear}
                disabled={clearing}
                className={`flex items-center gap-1.5 px-3 h-10 rounded-full border text-sm font-semibold transition-colors disabled:opacity-50 ${
                  confirmClear
                    ? 'border-[#fa3f5e] bg-[#fa3f5e] text-white'
                    : 'border-gray-200 dark:border-gray-800 text-gray-700 dark:text-gray-300 hover:border-[#fa3f5e] hover:text-[#fa3f5e]'
                }`}
              >
                {clearing ? <Loader2 size={15} className="animate-spin" /> : <Trash2 size={15} />}
                {confirmClear ? 'Confirm clear?' : 'Clear all'}
              </button>
            </>
          )}
        </div>
      </div>

      {/* Stats */}
      {!loading && count > 0 && (
        <div className="grid grid-cols-3 gap-3 my-5">
          {[
            { icon: Heart, label: 'Saved items', value: String(count) },
            { icon: ShoppingBag, label: 'Total value', value: money(totalValue) },
            { icon: Star, label: 'Avg rating', value: avgRating ? avgRating.toFixed(1) : '—' },
          ].map((stat) => {
            const StatIcon = stat.icon;
            return (
            <div key={stat.label} className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-3 sm:px-5 py-3.5 shadow-sm flex items-center gap-3">
              <span className="w-9 h-9 shrink-0 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center text-[#fa3f5e]"><StatIcon size={17} /></span>
              <div className="min-w-0"><p className="text-[11px] uppercase tracking-wide font-bold text-gray-400 dark:text-gray-500">{stat.label}</p><p className="text-sm sm:text-base font-bold text-gray-900 dark:text-white truncate">{stat.value}</p></div>
            </div>
            );
          })}
        </div>
      )}

      {/* Search + sort */}
      {!loading && count > 0 && (
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between mb-6">
          <div className="relative w-full lg:max-w-[420px]">
            <Search size={17} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="search"
              aria-label="Search wishlist"
              placeholder="Search your wishlist…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              className="w-full h-10 rounded-full border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 pl-10 pr-4 text-sm text-gray-900 dark:text-white placeholder:text-gray-400 focus:outline-none focus:border-[#fa3f5e]"
            />
          </div>
          <label className="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
            Sort by
            <select
              value={sort}
              onChange={(e) => setSort(e.target.value)}
              className="h-10 rounded-full border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 px-3 text-sm font-semibold text-gray-700 dark:text-gray-200 focus:outline-none focus:border-[#fa3f5e]"
            >
              {SORTS.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}
            </select>
          </label>
        </div>
      )}

      {/* Notice / error */}
      {notice && (
        <div className="mb-4 rounded-xl border border-green-200 dark:border-green-900 bg-green-50 dark:bg-green-900/20 px-4 py-2.5 text-sm font-medium text-green-700 dark:text-green-300">
          {notice}
        </div>
      )}
      {error && (
        <div className="mb-4 rounded-xl border border-red-200 dark:border-red-900 bg-red-50 dark:bg-red-900/20 px-4 py-3 text-sm text-red-700 dark:text-red-300 flex flex-wrap items-center justify-between gap-2">
          <span>Couldn't load your wishlist: {error}</span>
          <button onClick={() => refresh()} className="font-bold underline underline-offset-2">Retry</button>
        </div>
      )}

      {/* Body */}
      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      ) : count === 0 && savedServices.length === 0 && !error ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <span className="mx-auto mb-4 w-16 h-16 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">
            <Heart size={30} className="text-[#fa3f5e]" />
          </span>
          <h2 className="font-bold text-gray-900 dark:text-white">Your wishlist is empty</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1.5">Tap the heart on any product to save it here — it syncs to your account.</p>
          <Link to="/market" className={`inline-flex items-center gap-1.5 mt-5 px-5 py-2.5 rounded-lg text-sm font-bold ${primaryBtn}`}>
            Explore Marketplace <ChevronRight size={15} />
          </Link>
        </div>
      ) : filtered.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-gray-200 dark:border-gray-800 px-4 py-14 text-center">
          <Search size={28} className="mx-auto text-gray-300 dark:text-gray-600 mb-3" />
          <p className="text-sm text-gray-500 dark:text-gray-400">No matches for “{query.trim()}”.</p>
          <button onClick={() => setQuery('')} className="mt-3 text-sm font-bold text-[#fa3f5e]">Clear search</button>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {filtered.map((product) => (
            <WishlistProductCard
              key={product.id}
              product={product}
              mutating={mutatingId != null && String(mutatingId) === String(product.id)}
              onRemove={() => remove(product.rawId ?? product.id)}
              onAddToCart={() => handleAddToCart(product)}
            />
          ))}
        </div>
      )}

      {/* Saved services (device-only, API is product-only) */}
      {!loading && savedServices.length > 0 && (
        <section className="mt-10">
          <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Saved services</h2>
          <p className="text-xs text-gray-400 dark:text-gray-500 mb-4">Kept on this device only — the wishlist API covers products.</p>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {savedServices.map((service) => (
              <ServiceCard
                key={`service-${service.id}`}
                service={service}
                showType
                isFavorite
                onToggleFavorite={() => untoggleLocal('service', service.id)}
              />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
