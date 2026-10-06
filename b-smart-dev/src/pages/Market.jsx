import React, { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { CheckCircle2, Heart, Star, Eye, Store, ShoppingCart, Package, UserRound, ReceiptText, Search, SlidersHorizontal, X } from 'lucide-react';
import { addItem } from '../store/cartSlice';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { servicePrice } from '../myStore/data/serviceFields';
import { getProfilePath } from '../utils/profilePath';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import influencerProductService from '../services/influencerProductService';
import influencerServiceService from '../services/influencerServiceService';
import InfluencerSwitchModal from '../components/InfluencerSwitchModal';

const FILTERS = ['All', 'Products', 'Services', 'Persons'];

const MarketCardSkeleton = () => (
  <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
    <div className="aspect-[4/3] animate-pulse bg-gray-100 dark:bg-gray-800" />
    <div className="space-y-3 p-4">
      <div className="h-3 w-20 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
      <div className="h-4 w-3/4 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
      <div className="h-3 w-24 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
      <div className="h-5 w-28 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
      <div className="flex gap-2 pt-1">
        <div className="h-9 flex-1 animate-pulse rounded-lg bg-gray-100 dark:bg-gray-800" />
        <div className="h-9 flex-1 animate-pulse rounded-lg bg-gray-100 dark:bg-gray-800" />
      </div>
    </div>
  </div>
);

export const ProductCard = ({ product, isFavorite, onToggleFavorite, cartQuantity = 0, showType = false, onFlyToCart }) => {
  const dispatch = useDispatch();
  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };
  const image = product.images?.[0];
  const [adding, setAdding] = useState(false);
  const imageRef = useRef(null);

  const handleAddToCart = async () => {
    if (adding) return;
    setAdding(true);
    dispatch(addItem({
      id: product.id,
      productId: product.id,
      name: product.name,
      price: product.price,
      category: product.category,
      images: product.images || [],
      image,
      qty: 1,
      variant: product.variants?.[0] ? { color: product.variants[0].color, size: product.variants[0].size || 'One Size' } : undefined,
      storeName: product.vendor,
      storeAvatar: product.seller?.avatar_url,
      storeType: 'Influencer Store',
      selected: true,
      saved: false,
    }));
    onFlyToCart?.(imageRef.current);
    window.setTimeout(() => setAdding(false), 250);
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
        <div className={`relative aspect-[4/3] flex items-center justify-center ${bg}`}>
          <Link to={`/market/product/${product.id}`} state={{ product }} aria-label={`View ${product.name}`} className="absolute inset-0 flex items-center justify-center">
            {image
              ? <img ref={imageRef} src={image} alt={product.name} className="w-full h-full object-cover" />
              : <Icon size={48} className={`${text} opacity-70`} />}
          </Link>
          <span className="absolute top-3 left-3 px-2 py-0.5 rounded-md bg-white/90 dark:bg-black/60 text-[10px] font-bold tracking-wide text-gray-700 dark:text-gray-200 uppercase">
            Market
          </span>
          <button
            type="button"
            aria-label={`${isFavorite ? 'Remove' : 'Add'} ${product.name} ${isFavorite ? 'from' : 'to'} wishlist`}
            aria-pressed={isFavorite}
            onClick={onToggleFavorite}
            className="absolute top-3 right-3 w-7 h-7 rounded-full bg-white dark:bg-gray-800 shadow flex items-center justify-center"
          >
            <Heart size={14} className={isFavorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-400'} />
          </button>
        </div>

      <div className="p-4">
        <p className={`text-[11px] font-bold uppercase tracking-wide mb-1 ${text}`}>{showType ? `Product · ${product.category}` : product.category}</p>
        <Link to={`/market/product/${product.id}`} state={{ product }}>
          <h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1.5 truncate hover:text-[#fa3f5e] transition-colors" title={product.name}>
            {product.name}
          </h3>
        </Link>
        <div className="flex items-center gap-1 text-xs text-gray-400 dark:text-gray-500 mb-2.5">
          <Star size={12} className="fill-amber-400 text-amber-400" />
          <span>{product.rating}</span>
          <span className="mx-1">·</span>
          <Eye size={12} />
          <span>{product.views}</span>
        </div>
        <p className="font-bold text-[#fa3f5e] mb-3">
          ₹{product.price.toFixed(2)} <span className="text-gray-400 dark:text-gray-500 text-xs font-normal">INR</span>
        </p>
        <div className="flex gap-2">
          <button
            onClick={handleAddToCart}
            disabled={adding}
            className="flex-1 py-1.5 rounded-lg text-xs font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
          >
            {adding ? 'Adding...' : cartQuantity > 0 ? `Added ${cartQuantity}` : 'Add to Cart'}
          </button>
          <Link
            to={`/market/product/${product.id}`}
            state={{ product }}
            className="flex-1 py-1.5 rounded-lg text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 text-center"
          >
            View Details
          </Link>
        </div>
      </div>
    </div>
  );
};

export const ServiceCard = ({ service, isFavorite, onToggleFavorite, showType = false }) => {
  const [imageFailed, setImageFailed] = useState(false);
  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
      <div className="relative aspect-[4/3] flex items-center justify-center bg-pink-50 dark:bg-gray-800">
        <Link to={`/market/service/${service.id}`} aria-label={`View ${service.name}`} className="absolute inset-0 flex items-center justify-center">
          {service.images?.[0] && !imageFailed ? <img src={service.images[0]} alt={service.name} onError={() => setImageFailed(true)} className="w-full h-full object-cover" /> : <ServiceIcon size={48} className="text-[#fa3f5e] opacity-70" />}
        </Link>
        <span className="absolute top-3 left-3 px-2 py-0.5 rounded-md bg-white/90 dark:bg-black/60 text-[10px] font-bold tracking-wide text-gray-700 dark:text-gray-200 uppercase">Market</span>
        <button type="button" aria-label={`${isFavorite ? 'Remove' : 'Add'} ${service.name} ${isFavorite ? 'from' : 'to'} wishlist`} aria-pressed={isFavorite} onClick={onToggleFavorite} className="absolute top-3 right-3 w-7 h-7 rounded-full bg-white dark:bg-gray-800 shadow flex items-center justify-center">
          <Heart size={14} className={isFavorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-400'} />
        </button>
      </div>
    <div className="p-4">
      <p className="text-[11px] font-bold uppercase tracking-wide mb-1 text-[#fa3f5e]">{showType ? `Service · ${service.category || 'Service'}` : service.category || 'Service'}</p>
      <Link to={`/market/service/${service.id}`}><h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1.5 truncate hover:text-[#fa3f5e] transition-colors" title={service.name}>{service.name}</h3></Link>
      <div className="flex items-center gap-1 text-xs text-gray-400 dark:text-gray-500 mb-2.5"><Star size={12} className="fill-amber-400 text-amber-400" /><span>{service.rating > 0 ? service.rating : 'New service'}</span><span className="mx-1">·</span><span>{service.duration || '1 hour'}</span></div>
      <p className="font-bold text-[#fa3f5e] mb-3">{servicePrice(service)}</p>
      <Link to={`/market/service/${service.id}`} className="block text-center py-1.5 rounded-lg text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300">View Details</Link>
    </div>
    </div>
  );
};

const PersonCard = ({ user, productCount, serviceCount }) => {
  const name = user.name || user.full_name || user.username || 'Store owner';
  const avatar = user.profile_picture || user.avatar || user.avatar_url;
  const profilePath = user._id || user.id ? getProfilePath(user) : '/profile';
  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
      <Link to={profilePath} className="block">
        <div className="relative aspect-[4/3] flex items-center justify-center bg-pink-50 dark:bg-gray-800">
          <span className="absolute top-3 left-3 px-2 py-0.5 rounded-md bg-white/90 dark:bg-black/60 text-[10px] font-bold tracking-wide text-gray-700 dark:text-gray-200 uppercase">Person</span>
          {avatar ? <img src={avatar} alt={name} className="w-20 h-20 rounded-full object-cover" /> : <span className="w-20 h-20 rounded-full bg-white dark:bg-gray-900 flex items-center justify-center"><UserRound size={40} className="text-[#fa3f5e]" /></span>}
        </div>
      </Link>
      <div className="p-4">
        <p className="text-[11px] font-bold uppercase tracking-wide mb-1 text-[#fa3f5e]">Store creator</p>
        <Link to={profilePath}><h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1.5 truncate hover:text-[#fa3f5e] transition-colors" title={name}>{name}</h3></Link>
        <p className="text-xs text-gray-400 dark:text-gray-500 mb-2.5">{productCount} {productCount === 1 ? 'product' : 'products'} · {serviceCount} {serviceCount === 1 ? 'service' : 'services'}</p>
        <p className="font-bold text-[#fa3f5e] mb-3">Marketplace creator</p>
        <Link to={profilePath} className="block text-center py-1.5 rounded-lg text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300">View Profile</Link>
      </div>
    </div>
  );
};

const Market = () => {
  const [activeFilter, setActiveFilter] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [apiProducts, setApiProducts] = useState([]);
  const [apiServices, setApiServices] = useState([]);
  const [productsLoading, setProductsLoading] = useState(true);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [productsError, setProductsError] = useState('');
  const [servicesError, setServicesError] = useState('');
  const [filterOpen, setFilterOpen] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState('All categories');
  const [sortBy, setSortBy] = useState('Recommended');
  const [minPrice, setMinPrice] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const { isSaved, toggle } = useMarketplaceWishlist();
  const mockProducts = useSelector((state) => state.products.items);
  const mockServices = useSelector((state) => state.services.items);
  const user = useSelector((state) => state.auth.userObject);
  const cartItems = useSelector((state) => state.cart.items);
  const cartCount = cartItems.reduce((sum, i) => sum + i.qty, 0);
  const isInfluencer = user?.role === 'influencer';
  const [showInfluencerModal, setShowInfluencerModal] = useState(false);
  const [wishlistPopup, setWishlistPopup] = useState('');
  const cartIconRef = useRef(null);

  useEffect(() => {
    let alive = true;
    influencerProductService.list()
      .then((items) => {
        if (!alive) return;
        setApiProducts(items);
        setProductsError('');
      })
      .catch((err) => {
        if (!alive) return;
        setProductsError(err?.response?.data?.message || 'Could not load live products.');
      })
      .finally(() => {
        if (alive) setProductsLoading(false);
      });
    return () => { alive = false; };
  }, []);

  useEffect(() => {
    if (!wishlistPopup) return undefined;
    const timeout = window.setTimeout(() => setWishlistPopup(''), 1800);
    return () => window.clearTimeout(timeout);
  }, [wishlistPopup]);

  useEffect(() => {
    let alive = true;
    influencerServiceService.list()
      .then((items) => {
        if (!alive) return;
        setApiServices(items);
        setServicesError('');
      })
      .catch((err) => {
        if (!alive) return;
        setServicesError(err?.response?.data?.message || 'Could not load live services.');
      })
      .finally(() => {
        if (alive) setServicesLoading(false);
      });
    return () => { alive = false; };
  }, []);

  const query = searchQuery.trim().toLowerCase();
  const matchesQuery = (...values) => !query || values.some((value) => String(value ?? '').toLowerCase().includes(query));
  const allProducts = apiProducts.length > 0 ? apiProducts : mockProducts;
  const allServices = apiServices.length > 0 ? apiServices : mockServices;
  const listedProducts = allProducts.filter((item) => (item.status || (item.rating > 0 ? 'Active' : 'Draft')) === 'Active');
  const listedServices = allServices.filter((item) => item.status === 'Published' && item.visible);
  const categories = ['All categories', ...new Set([...listedProducts, ...listedServices].map((item) => item.category).filter(Boolean))];
  const min = minPrice === '' ? null : Number(minPrice);
  const max = maxPrice === '' ? null : Number(maxPrice);
  const matchesCategory = (item) => categoryFilter === 'All categories' || item.category === categoryFilter;
  const matchesPrice = (item) => {
    const price = Number(item.price || 0);
    return (min == null || price >= min) && (max == null || price <= max);
  };
  const sortListings = (items) => [...items].sort((a, b) => {
    if (sortBy === 'Price: Low to high') return Number(a.price || 0) - Number(b.price || 0);
    if (sortBy === 'Price: High to low') return Number(b.price || 0) - Number(a.price || 0);
    if (sortBy === 'Top rated') return Number(b.rating || 0) - Number(a.rating || 0);
    return 0;
  });
  const products = sortListings(listedProducts.filter((item) => matchesQuery(item.name, item.category, item.vendor, item.description) && matchesCategory(item) && matchesPrice(item)));
  const services = sortListings(listedServices.filter((item) => matchesQuery(item.name, item.category, item.provider, item.description, ...((item.subservices || []).map((subservice) => subservice.name))) && matchesCategory(item) && matchesPrice(item)));
  const showProducts = activeFilter === 'All' || activeFilter === 'Products';
  const showServices = activeFilter === 'All' || activeFilter === 'Services';
  const showPersons = activeFilter === 'All' || activeFilter === 'Persons';
  const showCreator = !!user && (listedProducts.length > 0 || listedServices.length > 0) && matchesQuery(user.name, user.full_name, user.username);
  const isShowingSkeletons = (showProducts && productsLoading) || (showServices && servicesLoading);
  const skeletonCount = activeFilter === 'All' ? 4 : 8;
  const hasResults = isShowingSkeletons || (showProducts && products.length > 0) || (showServices && services.length > 0) || (showPersons && showCreator);
  const activeFilters = [
    activeFilter !== 'All' ? activeFilter : null,
    categoryFilter !== 'All categories' ? categoryFilter : null,
    minPrice !== '' ? `Min Rs ${minPrice}` : null,
    maxPrice !== '' ? `Max Rs ${maxPrice}` : null,
    sortBy !== 'Recommended' ? sortBy : null,
  ].filter(Boolean);
  const clearFilters = () => {
    setActiveFilter('All');
    setCategoryFilter('All categories');
    setSortBy('Recommended');
    setMinPrice('');
    setMaxPrice('');
  };
  const animateProductToCart = (sourceImage) => {
    const cartTarget = cartIconRef.current;
    if (!sourceImage || !cartTarget || typeof sourceImage.getBoundingClientRect !== 'function') return;
    const sourceRect = sourceImage.getBoundingClientRect();
    const targetRect = cartTarget.getBoundingClientRect();
    if (!sourceRect.width || !sourceRect.height || !targetRect.width || !targetRect.height) return;

    const clone = sourceImage.cloneNode(true);
    clone.removeAttribute('id');
    Object.assign(clone.style, {
      position: 'fixed',
      left: `${sourceRect.left}px`,
      top: `${sourceRect.top}px`,
      width: `${sourceRect.width}px`,
      height: `${sourceRect.height}px`,
      objectFit: 'cover',
      borderRadius: '16px',
      pointerEvents: 'none',
      zIndex: '9999',
      boxShadow: '0 18px 45px rgba(15, 23, 42, 0.22)',
      transformOrigin: 'center',
    });
    document.body.appendChild(clone);

    const sourceCenterX = sourceRect.left + sourceRect.width / 2;
    const sourceCenterY = sourceRect.top + sourceRect.height / 2;
    const targetCenterX = targetRect.left + targetRect.width / 2;
    const targetCenterY = targetRect.top + targetRect.height / 2;
    const deltaX = targetCenterX - sourceCenterX;
    const deltaY = targetCenterY - sourceCenterY;
    const lift = Math.min(140, Math.max(60, Math.abs(deltaY) * 0.35));

    clone.animate([
      { transform: 'translate3d(0, 0, 0) scale(1)', opacity: 1 },
      { transform: `translate3d(${deltaX * 0.45}px, ${deltaY * 0.45 - lift}px, 0) scale(0.62)`, opacity: 0.9, offset: 0.55 },
      { transform: `translate3d(${deltaX}px, ${deltaY}px, 0) scale(0.16)`, opacity: 0 },
    ], {
      duration: 760,
      easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
      fill: 'forwards',
    }).onfinish = () => {
      clone.remove();
      cartTarget.animate([
        { transform: 'scale(1)' },
        { transform: 'scale(1.16)' },
        { transform: 'scale(1)' },
      ], {
        duration: 280,
        easing: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
      });
    };
  };
  const toggleProductWishlist = (product) => {
    const alreadySaved = isSaved('product', product.id);
    toggle('product', product.id, product);
    if (!alreadySaved) setWishlistPopup('Added to wishlist');
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      {wishlistPopup && (
        <div role="status" aria-live="polite" className="fixed bottom-6 left-1/2 z-[80] flex -translate-x-1/2 items-center gap-2 rounded-xl border border-pink-100 bg-white px-4 py-3 text-sm font-semibold text-gray-900 shadow-xl dark:border-gray-800 dark:bg-gray-900 dark:text-white">
          <CheckCircle2 size={18} className="text-[#fa3f5e]" />
          {wishlistPopup}
        </div>
      )}
      <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Marketplace</h1>
        <div className="flex flex-wrap items-center gap-2">
          <Link
            to="/market/wishlist"
            className="flex items-center gap-1.5 px-3 h-10 rounded-full border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-700"
          >
            <Heart size={16} /> Wishlist
          </Link>
          <Link
            to="/market/my-orders"
            className="flex items-center gap-1.5 px-3 h-10 rounded-full border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-700"
          >
            <ReceiptText size={16} /> My Orders
          </Link>
          {isInfluencer ? (
            <Link
              to="/market/my-store"
              className="flex items-center gap-1.5 px-3 h-10 rounded-full border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-700"
            >
              <Store size={16} /> My Store
            </Link>
          ) : (
            <button
              type="button"
              onClick={() => setShowInfluencerModal(true)}
              className="flex items-center gap-1.5 px-3 h-10 rounded-full text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
            >
              <Store size={16} /> Become an Influencer
            </button>
          )}
          <Link
            to="/cart"
            ref={cartIconRef}
            className="relative w-10 h-10 rounded-full border border-gray-200 dark:border-gray-800 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-700"
          >
            <ShoppingCart size={18} />
            {cartCount > 0 && (
              <span className="absolute -top-1.5 -right-1.5 min-w-[18px] h-[18px] px-1 rounded-full bg-[#fa3f5e] text-white text-[10px] font-bold flex items-center justify-center leading-none">
                {cartCount > 99 ? '99+' : cartCount}
              </span>
            )}
          </Link>
        </div>
      </div>

      <div className="mb-6 rounded-2xl border border-gray-100 bg-white p-2 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <div className="flex flex-col gap-2 md:flex-row md:items-center">
          <div className="relative min-w-0 flex-1">
            <Search size={17} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="search"
              aria-label="Search Marketplace"
              placeholder="Search products, services, creators..."
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              className="h-11 w-full rounded-xl border border-transparent bg-gray-50 pl-10 pr-4 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none focus:border-[#fa3f5e] focus:bg-white dark:bg-gray-800 dark:text-white dark:focus:bg-gray-900"
            />
          </div>
          <div className="md:shrink-0">
          <button
            type="button"
            aria-expanded={filterOpen}
            onClick={() => setFilterOpen(true)}
            className={`relative flex h-11 w-full items-center justify-center gap-2 rounded-xl border px-4 text-sm font-semibold transition-colors md:w-auto ${filterOpen || activeFilters.length ? 'border-[#fa3f5e] bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/10' : 'border-gray-200 text-gray-700 hover:border-gray-300 dark:border-gray-700 dark:text-gray-300 dark:hover:border-gray-600'}`}
          >
            <SlidersHorizontal size={16} /> Filter
            {activeFilters.length > 0 && <span className="ml-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-[#fa3f5e] px-1.5 text-[10px] font-bold text-white">{activeFilters.length}</span>}
          </button>
          </div>
        </div>
        {activeFilters.length > 0 && (
          <div className="flex flex-wrap items-center gap-2 px-1 pb-1 pt-2">
            {activeFilters.map((filter) => (
              <span key={filter} className="rounded-full bg-pink-50 px-3 py-1 text-[11px] font-semibold text-[#fa3f5e] dark:bg-pink-900/10">{filter}</span>
            ))}
            <button type="button" onClick={clearFilters} className="text-[11px] font-bold text-gray-500 hover:text-[#fa3f5e] dark:text-gray-400">Clear all</button>
          </div>
        )}
      </div>

      <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Featured in Market</h2>
      <p className="text-xs text-gray-400 dark:text-gray-500 mb-6">
        {productsLoading || servicesLoading
          ? 'Loading live influencer listings...'
          : productsError || servicesError
          ? `${productsError || servicesError} Showing local fallback listings where needed.`
          : 'Showing live influencer products and services.'}
      </p>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        {isShowingSkeletons && Array.from({ length: skeletonCount }, (_, index) => <MarketCardSkeleton key={`market-loading-${index}`} />)}
        {!isShowingSkeletons && showProducts && products.map((p) => (
          <ProductCard
            key={p.id}
            product={p}
            isFavorite={isSaved('product', p.id)}
            onToggleFavorite={() => toggleProductWishlist(p)}
            onFlyToCart={animateProductToCart}
            cartQuantity={cartItems.find((item) => String(item.productId || item.id) === String(p.id))?.qty || 0}
          />
        ))}
        {!isShowingSkeletons && showServices && services.map((service) => (
          <ServiceCard key={`service-${service.id}`} service={service} isFavorite={isSaved('service', service.id)} onToggleFavorite={() => toggle('service', service.id)} />
        ))}
        {!isShowingSkeletons && showPersons && showCreator && <PersonCard key={user._id || user.id || 'store-creator'} user={user} productCount={listedProducts.length} serviceCount={listedServices.length} />}
        {!hasResults && (
          <p className="col-span-full text-center text-gray-400 dark:text-gray-500 py-10">
            {query ? `No results for “${searchQuery.trim()}”.` : `No ${activeFilter === 'All' ? 'marketplace listings' : activeFilter.toLowerCase()} yet.`}
          </p>
        )}
      </div>

      {filterOpen && (
        <div className="fixed inset-0 z-[70]">
          <button type="button" aria-label="Close filters" onClick={() => setFilterOpen(false)} className="absolute inset-0 bg-black/35" />
          <aside className="absolute right-0 top-0 flex h-full w-full max-w-[390px] flex-col bg-white shadow-2xl dark:bg-gray-900">
            <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4 dark:border-gray-800">
              <div>
                <h2 className="text-base font-bold text-gray-900 dark:text-white">Filters</h2>
                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Refine marketplace results</p>
              </div>
              <button type="button" onClick={() => setFilterOpen(false)} aria-label="Close filters" className="flex h-9 w-9 items-center justify-center rounded-full border border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800">
                <X size={18} />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-5 py-5">
              <div className="space-y-6">
                <fieldset>
                  <legend className="mb-3 text-xs font-bold uppercase tracking-wide text-gray-400">Show</legend>
                  <div className="grid grid-cols-2 gap-2">
                    {FILTERS.map((filter) => (
                      <button key={filter} type="button" onClick={() => setActiveFilter(filter)} className={`rounded-xl border px-3 py-2.5 text-xs font-semibold transition-colors ${activeFilter === filter ? 'border-[#fa3f5e] bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/10' : 'border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'}`}>{filter}</button>
                    ))}
                  </div>
                </fieldset>
                <label className="block text-xs font-bold uppercase tracking-wide text-gray-400">
                  Category
                  <select value={categoryFilter} onChange={(event) => setCategoryFilter(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-sm font-semibold normal-case tracking-normal text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white">
                    {categories.map((category) => <option key={category} value={category}>{category}</option>)}
                  </select>
                </label>
                <div>
                  <p className="mb-2 text-xs font-bold uppercase tracking-wide text-gray-400">Price range</p>
                  <div className="grid grid-cols-2 gap-2">
                    <input type="number" min="0" value={minPrice} onChange={(event) => setMinPrice(event.target.value)} placeholder="Min" className="h-11 rounded-xl border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white" />
                    <input type="number" min="0" value={maxPrice} onChange={(event) => setMaxPrice(event.target.value)} placeholder="Max" className="h-11 rounded-xl border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white" />
                  </div>
                </div>
                <label className="block text-xs font-bold uppercase tracking-wide text-gray-400">
                  Sort
                  <select value={sortBy} onChange={(event) => setSortBy(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-sm font-semibold normal-case tracking-normal text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white">
                    {['Recommended', 'Price: Low to high', 'Price: High to low', 'Top rated'].map((option) => <option key={option} value={option}>{option}</option>)}
                  </select>
                </label>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3 border-t border-gray-100 p-5 dark:border-gray-800">
              <button type="button" onClick={clearFilters} className="rounded-xl border border-gray-200 py-3 text-sm font-bold text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800">Clear</button>
              <button type="button" onClick={() => setFilterOpen(false)} className="rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange py-3 text-sm font-bold text-white">Apply</button>
            </div>
          </aside>
        </div>
      )}

      <InfluencerSwitchModal isOpen={showInfluencerModal} onClose={() => setShowInfluencerModal(false)} />
    </div>
  );
};

export default Market;
