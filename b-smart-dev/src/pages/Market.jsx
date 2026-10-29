import React, { useEffect, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { CheckCircle2, Heart, Star, BadgeCheck, ShoppingCart, Package, UserRound, Search, SlidersHorizontal, X, Sparkles, ArrowRight, LayoutGrid, List, ChevronDown, ChevronLeft, ChevronRight, Briefcase, Check, Clock, Video, MapPin, Store } from 'lucide-react';
import { addItem } from '../store/cartSlice';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { servicePrice } from '../myStore/data/serviceFields';
import { getProfilePath } from '../utils/profilePath';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import influencerProductService from '../services/influencerProductService';
import influencerServiceService from '../services/influencerServiceService';

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

const METHOD_ICON = { Online: Video, 'At customer location': MapPin, 'At my location': Store };

export const ProductCard = ({ product, isFavorite, onToggleFavorite, cartQuantity = 0, showType = false, onFlyToCart }) => {
  const dispatch = useDispatch();
  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };
  const image = product.images?.[0];
  const vendorAvatar = product.seller?.avatar_url || product.seller?.profile_picture;
  const [adding, setAdding] = useState(false);
  const imageRef = useRef(null);
  const hasDiscount = product.mrp > product.price;
  const discountPercent = hasDiscount ? Math.round((1 - product.price / product.mrp) * 100) : 0;
  const lowStock = product.stockQuantity > 0 && product.stockQuantity <= 5;

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
    window.setTimeout(() => setAdding(false), 900);
  };

  return (
    <div className="flex flex-col bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-lg transition-shadow duration-200 overflow-hidden">
      <div className={`relative aspect-[4/3] flex items-center justify-center overflow-hidden ${bg}`}>
        <Link to={`/market/product/${product.id}`} state={{ product }} aria-label={`View ${product.name}`} className="absolute inset-0 flex items-center justify-center">
          {image
            ? <img ref={imageRef} src={image} alt={product.name} className="w-full h-full object-cover transition-transform duration-300 hover:scale-105" />
            : <Icon size={44} className={`${text} opacity-70`} />}
        </Link>
        <span className={`absolute top-3 left-3 flex items-center gap-1 px-2 py-1 rounded-lg bg-white/95 dark:bg-gray-900/95 text-[10px] font-bold tracking-wide uppercase ${text}`}>
          <Icon size={11} /> {showType ? `Product · ${product.category}` : product.category}
        </span>
        <button
          type="button"
          aria-label={`${isFavorite ? 'Remove' : 'Add'} ${product.name} ${isFavorite ? 'from' : 'to'} wishlist`}
          aria-pressed={isFavorite}
          onClick={onToggleFavorite}
          className="absolute top-3 right-3 flex h-8 w-8 items-center justify-center rounded-full bg-white/95 dark:bg-gray-900/95 shadow-sm hover:scale-110 transition-transform"
        >
          <Heart size={15} className={isFavorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-500'} />
        </button>
        {hasDiscount && (
          <span className="absolute bottom-3 left-3 rounded-full bg-emerald-500 px-2 py-0.5 text-[10px] font-bold text-white">SAVE {discountPercent}%</span>
        )}
        {lowStock && (
          <span className="absolute bottom-3 right-3 rounded-full bg-[#fa3f5e] px-2 py-0.5 text-[10px] font-bold uppercase text-white">Only {product.stockQuantity} left</span>
        )}
      </div>

      <div className="flex flex-1 flex-col p-4">
        <div className="flex items-center gap-1.5 mb-2 min-w-0">
          {vendorAvatar
            ? <img src={vendorAvatar} alt={product.vendor} className="w-5 h-5 rounded-full object-cover shrink-0" />
            : <span className="w-5 h-5 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0"><UserRound size={11} className="text-[#fa3f5e]" /></span>}
          <span className="text-xs font-semibold text-gray-600 dark:text-gray-400 truncate">{product.vendor}</span>
          {product.seller?.is_verified && <BadgeCheck size={13} className="text-[#fa3f5e] shrink-0" />}
        </div>
        <Link to={`/market/product/${product.id}`} state={{ product }}>
          <h3 className="font-bold text-gray-900 dark:text-white text-sm mb-2 line-clamp-2 leading-snug hover:text-[#fa3f5e] transition-colors" title={product.name}>
            {product.name}
          </h3>
        </Link>
        <div className="flex items-center gap-1 text-xs mb-3">
          <Star size={13} className="fill-amber-400 text-amber-400" />
          <span className="font-semibold text-gray-700 dark:text-gray-300">{product.rating > 0 ? product.rating : 'New'}</span>
          {product.reviews > 0 && <span className="text-gray-400 dark:text-gray-500">({product.reviews})</span>}
        </div>
        <div className="mt-auto flex items-center justify-between gap-3">
          <div>
            <p className="font-extrabold text-gray-900 dark:text-white text-base leading-none">₹{product.price.toFixed(2)}</p>
            {hasDiscount && <p className="text-xs text-gray-400 line-through">₹{product.mrp.toFixed(2)}</p>}
          </div>
          <button
            type="button"
            onClick={handleAddToCart}
            disabled={adding}
            aria-label={cartQuantity > 0 ? `Added to cart, add another ${product.name}` : `Add ${product.name} to cart`}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#fa3f5e] text-white shadow-sm hover:opacity-90 transition-opacity disabled:opacity-70"
          >
            {cartQuantity > 0 || adding ? <Check size={16} /> : <ShoppingCart size={15} />}
          </button>
        </div>
      </div>
    </div>
  );
};

export const ServiceCard = ({ service, isFavorite, onToggleFavorite, showType = false }) => {
  const [imageFailed, setImageFailed] = useState(false);
  const vendorAvatar = service.seller?.avatar_url || service.seller?.profile_picture;
  const MethodIcon = METHOD_ICON[service.method] || MapPin;

  return (
    <div className="flex flex-col bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-lg transition-shadow duration-200 overflow-hidden">
      <div className="relative aspect-[4/3] flex items-center justify-center overflow-hidden bg-pink-50 dark:bg-gray-800">
        <Link to={`/market/service/${service.id}`} aria-label={`View ${service.name}`} className="absolute inset-0 flex items-center justify-center">
          {service.images?.[0] && !imageFailed
            ? <img src={service.images[0]} alt={service.name} onError={() => setImageFailed(true)} className="w-full h-full object-cover transition-transform duration-300 hover:scale-105" />
            : <ServiceIcon size={44} className="text-[#fa3f5e] opacity-70" />}
        </Link>
        <span className="absolute top-3 left-3 flex items-center gap-1 px-2 py-1 rounded-lg bg-white/95 dark:bg-gray-900/95 text-[10px] font-bold tracking-wide uppercase text-[#fa3f5e]">
          <ServiceIcon size={11} /> {showType ? `Service · ${service.category || 'Service'}` : service.category || 'Service'}
        </span>
        <span className="absolute top-3 right-3 flex items-center gap-1 px-2 py-1 rounded-lg bg-white/95 dark:bg-gray-900/95 text-[10px] font-bold text-gray-600 dark:text-gray-300">
          <MethodIcon size={11} /> {service.method}
        </span>
        <button
          type="button"
          aria-label={`${isFavorite ? 'Remove' : 'Add'} ${service.name} ${isFavorite ? 'from' : 'to'} wishlist`}
          aria-pressed={isFavorite}
          onClick={onToggleFavorite}
          className="absolute bottom-3 right-3 flex h-8 w-8 items-center justify-center rounded-full bg-white/95 dark:bg-gray-900/95 shadow-sm hover:scale-110 transition-transform"
        >
          <Heart size={15} className={isFavorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-500'} />
        </button>
      </div>

      <div className="flex flex-1 flex-col p-4">
        <div className="flex items-center gap-1.5 mb-2 min-w-0">
          {vendorAvatar
            ? <img src={vendorAvatar} alt={service.provider} className="w-5 h-5 rounded-full object-cover shrink-0" />
            : <span className="w-5 h-5 rounded-full bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center shrink-0"><UserRound size={11} className="text-[#fa3f5e]" /></span>}
          <span className="text-xs font-semibold text-gray-600 dark:text-gray-400 truncate">{service.provider || 'Creator'}</span>
          {service.seller?.is_verified && <BadgeCheck size={13} className="text-[#fa3f5e] shrink-0" />}
        </div>

        <Link to={`/market/service/${service.id}`}>
          <h3 className="font-bold text-gray-900 dark:text-white text-sm mb-2 line-clamp-2 leading-snug hover:text-[#fa3f5e] transition-colors" title={service.name}>{service.name}</h3>
        </Link>

        <div className="flex items-center gap-3 text-xs text-gray-500 dark:text-gray-400 mb-3">
          <span className="flex items-center gap-1"><Clock size={12} /> {service.duration || '1 hour'}</span>
          <span className="flex items-center gap-1"><Star size={12} className="fill-amber-400 text-amber-400" /> {service.rating > 0 ? service.rating : 'New'}{service.reviews > 0 && <span className="text-gray-400">({service.reviews})</span>}</span>
        </div>

        <div className="mt-auto flex items-center justify-between gap-3">
          <div>
            <p className="text-[10px] font-bold uppercase tracking-wide text-gray-400">{service.rateType}</p>
            <p className="font-extrabold text-gray-900 dark:text-white text-base leading-none">{servicePrice(service)}</p>
          </div>
          <Link
            to={`/market/service/${service.id}`}
            className="flex h-10 shrink-0 items-center rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange px-4 text-xs font-bold text-white hover:opacity-90 transition-opacity"
          >
            View &amp; Book
          </Link>
        </div>
      </div>
    </div>
  );
};

const PersonCard = ({ user, productCount, serviceCount }) => {
  const name = user.name || user.full_name || user.username || 'Store owner';
  const avatar = user.profile_picture || user.avatar || user.avatar_url;
  const profilePath = user._id || user.id ? getProfilePath(user) : '/profile';
  return (
    <div className="group bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200 overflow-hidden">
      <Link to={profilePath} className="block">
        <div className="relative aspect-[4/3] flex items-center justify-center overflow-hidden bg-gradient-to-br from-insta-purple/10 via-insta-pink/10 to-insta-orange/10 dark:from-gray-800 dark:via-gray-800 dark:to-gray-800">
          <span className="absolute top-3 left-3 flex items-center gap-1 px-2 py-1 rounded-lg bg-white/95 dark:bg-gray-900/95 text-[10px] font-bold tracking-wide uppercase text-[#fa3f5e]">
            <UserRound size={11} /> Creator
          </span>
          {avatar
            ? <img src={avatar} alt={name} className="w-20 h-20 rounded-full object-cover ring-4 ring-white dark:ring-gray-900 shadow-md" />
            : <span className="w-20 h-20 rounded-full bg-white dark:bg-gray-900 ring-4 ring-white dark:ring-gray-900 shadow-md flex items-center justify-center"><UserRound size={40} className="text-[#fa3f5e]" /></span>}
        </div>
      </Link>
      <div className="p-4">
        <div className="flex items-center gap-1.5 mb-2">
          <Link to={profilePath} className="min-w-0"><h3 className="font-bold text-gray-900 dark:text-white text-sm truncate hover:text-[#fa3f5e] transition-colors" title={name}>{name}</h3></Link>
          {user.is_verified && <BadgeCheck size={13} className="text-[#fa3f5e] shrink-0" />}
        </div>
        <p className="text-xs text-gray-400 dark:text-gray-500 mb-3">{productCount} {productCount === 1 ? 'product' : 'products'} · {serviceCount} {serviceCount === 1 ? 'service' : 'services'}</p>
        <Link to={profilePath} className="block text-center py-2 rounded-lg text-xs font-bold bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white hover:opacity-90 transition-opacity">View Profile</Link>
      </div>
    </div>
  );
};

const Market = () => {
  const [searchParams] = useSearchParams();
  const [activeFilter, setActiveFilter] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [apiProducts, setApiProducts] = useState([]);
  const [apiServices, setApiServices] = useState([]);
  const [productsLoading, setProductsLoading] = useState(true);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [productsError, setProductsError] = useState('');
  const [servicesError, setServicesError] = useState('');
  const [filterOpen, setFilterOpen] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState(() => searchParams.get('category') || 'All categories');
  const [sortBy, setSortBy] = useState('Recommended');
  const [minPrice, setMinPrice] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const [viewMode, setViewMode] = useState('grid');
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 8;
  const { isSaved, toggle } = useMarketplaceWishlist();
  const mockProducts = useSelector((state) => state.products.items);
  const mockServices = useSelector((state) => state.services.items);
  const user = useSelector((state) => state.auth.userObject);
  const cartItems = useSelector((state) => state.cart.items);
  const [wishlistPopup, setWishlistPopup] = useState('');

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
  const displayItems = [
    ...(showProducts ? products.map((item) => ({ key: `product-${item.id}`, type: 'product', data: item })) : []),
    ...(showServices ? services.map((item) => ({ key: `service-${item.id}`, type: 'service', data: item })) : []),
    ...(showPersons && showCreator ? [{ key: 'store-creator', type: 'person', data: user }] : []),
  ];
  const totalItems = displayItems.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const pageItems = isShowingSkeletons ? [] : displayItems.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);
  const rangeStart = totalItems === 0 ? 0 : (currentPage - 1) * PAGE_SIZE + 1;
  const rangeEnd = Math.min(currentPage * PAGE_SIZE, totalItems);
  const pageNumbers = (() => {
    if (totalPages <= 7) return Array.from({ length: totalPages }, (_, i) => i + 1);
    const pages = new Set([1, 2, currentPage - 1, currentPage, currentPage + 1, totalPages - 1, totalPages]);
    return [...pages].filter((n) => n >= 1 && n <= totalPages).sort((a, b) => a - b);
  })();
  const applyActiveFilter = (value) => { setActiveFilter(value); setPage(1); };
  const applyCategoryFilter = (value) => { setCategoryFilter(value); setPage(1); };
  const applySortBy = (value) => { setSortBy(value); setPage(1); };
  const applyMinPrice = (value) => { setMinPrice(value); setPage(1); };
  const applyMaxPrice = (value) => { setMaxPrice(value); setPage(1); };
  const applySearchQuery = (value) => { setSearchQuery(value); setPage(1); };
  const activeFilters = [
    activeFilter !== 'All' ? { key: 'type', label: activeFilter, onRemove: () => applyActiveFilter('All') } : null,
    categoryFilter !== 'All categories' ? { key: 'category', label: categoryFilter, onRemove: () => applyCategoryFilter('All categories') } : null,
    minPrice !== '' ? { key: 'min', label: `Min ₹${minPrice}`, onRemove: () => applyMinPrice('') } : null,
    maxPrice !== '' ? { key: 'max', label: `Max ₹${maxPrice}`, onRemove: () => applyMaxPrice('') } : null,
    sortBy !== 'Recommended' ? { key: 'sort', label: sortBy, onRemove: () => applySortBy('Recommended') } : null,
  ].filter(Boolean);
  const clearFilters = () => {
    applyActiveFilter('All');
    applyCategoryFilter('All categories');
    applySortBy('Recommended');
    applyMinPrice('');
    applyMaxPrice('');
  };
  const animateProductToCart = (sourceImage) => {
    const cartTarget = document.getElementById('marketplace-cart-icon');
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
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] mx-auto px-4 pt-6">
      {wishlistPopup && (
        <div role="status" aria-live="polite" className="fixed bottom-6 left-1/2 z-[80] flex -translate-x-1/2 items-center gap-2 rounded-xl border border-pink-100 bg-white px-4 py-3 text-sm font-semibold text-gray-900 shadow-xl dark:border-gray-800 dark:bg-gray-900 dark:text-white">
          <CheckCircle2 size={18} className="text-[#fa3f5e]" />
          {wishlistPopup}
        </div>
      )}
      {/* Hero banner */}
      <section className="relative mb-14">
        <div className="overflow-hidden rounded-2xl bg-gradient-to-r from-[#962fbf] via-[#d62976] to-[#fa7e1e] px-6 py-10 sm:px-10 sm:py-12 shadow-lg">
          <div className="relative z-10 max-w-xl">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-[11px] font-bold uppercase tracking-wide text-white backdrop-blur-sm">
              <Sparkles size={12} /> Direct creator economy drop
            </span>
            <h1 className="mt-4 text-3xl sm:text-4xl font-extrabold leading-tight text-white">
              Discover products &amp; services from creators
            </h1>
            <p className="mt-3 max-w-lg text-sm text-white/85">
              Exclusive digital drops, masterclasses, physical merchandise, and 1-on-1 consultations directly from top creators.
            </p>
            <div className="mt-5 flex flex-wrap gap-2">
              <span className="flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold text-white backdrop-blur-sm">
                <Package size={12} /> {listedProducts.length}+ Products
              </span>
              <span className="flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold text-white backdrop-blur-sm">
                <Briefcase size={12} /> {listedServices.length}+ Services
              </span>
              <span className="flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold text-white backdrop-blur-sm">
                <CheckCircle2 size={12} /> Verified Creators
              </span>
            </div>
          </div>
        </div>

        <div className="absolute inset-x-4 sm:inset-x-10 -bottom-7 z-20">
          <div className="flex items-center gap-1 rounded-full bg-white p-1.5 shadow-xl ring-1 ring-black/5">
            <Search size={17} className="ml-3 shrink-0 text-gray-400" />
            <input
              type="search"
              aria-label="Search Marketplace"
              placeholder="Search products, services, creators..."
              value={searchQuery}
              onChange={(event) => applySearchQuery(event.target.value)}
              className="h-10 min-w-0 flex-1 bg-transparent px-1 text-sm text-gray-900 placeholder:text-gray-400 outline-none"
            />
            <button
              type="button"
              onClick={() => searchQuery && applySearchQuery(searchQuery)}
              className="flex h-10 shrink-0 items-center gap-1.5 rounded-full bg-[#fa3f5e] px-5 text-sm font-bold text-white hover:opacity-90 transition-opacity"
            >
              Search <ArrowRight size={14} />
            </button>
          </div>
        </div>
      </section>

      {/* Filter toolbar */}
      <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-1 rounded-full bg-gray-50 dark:bg-gray-900 p-1">
          {FILTERS.map((filter) => (
            <button
              key={filter}
              type="button"
              onClick={() => applyActiveFilter(filter)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition-colors ${
                activeFilter === filter
                  ? 'bg-gradient-to-r from-[#962fbf] via-[#d62976] to-[#fa7e1e] text-white shadow'
                  : 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
              }`}
            >
              {filter}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            aria-expanded={filterOpen}
            onClick={() => setFilterOpen(true)}
            className={`relative flex h-10 items-center justify-center gap-2 rounded-full border px-4 text-sm font-semibold transition-colors ${filterOpen || activeFilters.length ? 'border-[#fa3f5e] bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/10' : 'border-gray-200 text-gray-700 hover:border-gray-300 dark:border-gray-700 dark:text-gray-300 dark:hover:border-gray-600'}`}
          >
            <SlidersHorizontal size={15} /> Filters
            {activeFilters.length > 0 && <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-[#fa3f5e] px-1.5 text-[10px] font-bold text-white">{activeFilters.length}</span>}
          </button>

          <div className="relative">
            <select
              aria-label="Sort by"
              value={sortBy}
              onChange={(event) => applySortBy(event.target.value)}
              className="h-10 appearance-none rounded-full border border-gray-200 bg-white pl-4 pr-9 text-sm font-semibold text-gray-700 outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300"
            >
              {['Recommended', 'Price: Low to high', 'Price: High to low', 'Top rated'].map((option) => (
                <option key={option} value={option}>Sort: {option}</option>
              ))}
            </select>
            <ChevronDown size={14} className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" />
          </div>

          <div className="flex items-center gap-0.5 rounded-full border border-gray-200 dark:border-gray-700 p-1">
            <button
              type="button"
              aria-label="Grid view"
              aria-pressed={viewMode === 'grid'}
              onClick={() => setViewMode('grid')}
              className={`flex h-8 w-8 items-center justify-center rounded-full transition-colors ${viewMode === 'grid' ? 'bg-gray-900 text-white dark:bg-white dark:text-gray-900' : 'text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'}`}
            >
              <LayoutGrid size={14} />
            </button>
            <button
              type="button"
              aria-label="List view"
              aria-pressed={viewMode === 'list'}
              onClick={() => setViewMode('list')}
              className={`flex h-8 w-8 items-center justify-center rounded-full transition-colors ${viewMode === 'list' ? 'bg-gray-900 text-white dark:bg-white dark:text-gray-900' : 'text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'}`}
            >
              <List size={14} />
            </button>
          </div>
        </div>
      </div>

      {activeFilters.length > 0 && (
        <div className="mb-5 flex flex-wrap items-center gap-2">
          <span className="text-[11px] font-bold uppercase tracking-wide text-gray-400">Active:</span>
          {activeFilters.map((filter) => (
            <span key={filter.key} className="flex items-center gap-1.5 rounded-full bg-pink-50 dark:bg-pink-900/10 pl-3 pr-2 py-1 text-[11px] font-semibold text-[#fa3f5e]">
              {filter.label}
              <button type="button" onClick={filter.onRemove} aria-label={`Remove ${filter.label} filter`} className="flex h-4 w-4 items-center justify-center rounded-full hover:bg-pink-100 dark:hover:bg-pink-900/30">
                <X size={11} />
              </button>
            </span>
          ))}
          <button type="button" onClick={clearFilters} className="text-[11px] font-bold text-gray-500 hover:text-[#fa3f5e] dark:text-gray-400 underline underline-offset-2">Clear all</button>
        </div>
      )}

      {/* Explore categories */}
      <div className="mb-6">
        <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Explore Categories</h2>
        <div className="flex flex-wrap gap-2.5">
          <button
            type="button"
            onClick={() => applyCategoryFilter('All categories')}
            className={`flex items-center gap-2.5 rounded-2xl border px-3.5 py-2 transition-all duration-150 ${
              categoryFilter === 'All categories'
                ? 'border-[#fa3f5e] bg-pink-50 dark:bg-pink-900/10 shadow-sm'
                : 'border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700 hover:-translate-y-0.5'
            }`}
          >
            <span className="w-9 h-9 rounded-xl bg-gradient-to-br from-insta-purple via-insta-pink to-insta-orange flex items-center justify-center shrink-0">
              <LayoutGrid size={16} className="text-white" />
            </span>
            <span className={`text-sm font-semibold ${categoryFilter === 'All categories' ? 'text-[#fa3f5e]' : 'text-gray-700 dark:text-gray-300'}`}>All</span>
          </button>
          {Object.entries(CATEGORY_STYLE).map(([name, { icon: CatIcon, text, bg }]) => {
            const active = categoryFilter === name;
            return (
              <button
                key={name}
                type="button"
                onClick={() => applyCategoryFilter(active ? 'All categories' : name)}
                className={`flex items-center gap-2.5 rounded-2xl border px-3.5 py-2 transition-all duration-150 ${
                  active
                    ? 'border-[#fa3f5e] bg-pink-50 dark:bg-pink-900/10 shadow-sm'
                    : 'border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700 hover:-translate-y-0.5'
                }`}
              >
                <span className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${bg}`}>
                  <CatIcon size={17} className={text} />
                </span>
                <span className={`text-sm font-semibold ${active ? 'text-[#fa3f5e]' : 'text-gray-700 dark:text-gray-300'}`}>{name}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="flex items-center justify-between mb-4">
        <p className="text-xs text-gray-400 dark:text-gray-500">
          {productsLoading || servicesLoading
            ? 'Loading live influencer listings...'
            : productsError || servicesError
            ? `${productsError || servicesError} Showing local fallback listings where needed.`
            : `Showing ${totalItems} drop${totalItems === 1 ? '' : 's'} from verified creators`}
        </p>
      </div>

      <div className={viewMode === 'grid' ? 'grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4' : 'grid grid-cols-1 gap-4'}>
        {isShowingSkeletons && Array.from({ length: skeletonCount }, (_, index) => <MarketCardSkeleton key={`market-loading-${index}`} />)}
        {!isShowingSkeletons && pageItems.map((item) => {
          if (item.type === 'product') {
            return (
              <ProductCard
                key={item.key}
                product={item.data}
                isFavorite={isSaved('product', item.data.id)}
                onToggleFavorite={() => toggleProductWishlist(item.data)}
                onFlyToCart={animateProductToCart}
                cartQuantity={cartItems.find((cartItem) => String(cartItem.productId || cartItem.id) === String(item.data.id))?.qty || 0}
              />
            );
          }
          if (item.type === 'service') {
            return <ServiceCard key={item.key} service={item.data} isFavorite={isSaved('service', item.data.id)} onToggleFavorite={() => toggle('service', item.data.id)} />;
          }
          return <PersonCard key={item.key} user={item.data} productCount={listedProducts.length} serviceCount={listedServices.length} />;
        })}
        {!hasResults && (
          <p className="col-span-full text-center text-gray-400 dark:text-gray-500 py-10">
            {query ? `No results for “${searchQuery.trim()}”.` : `No ${activeFilter === 'All' ? 'marketplace listings' : activeFilter.toLowerCase()} yet.`}
          </p>
        )}
      </div>

      {!isShowingSkeletons && totalItems > 0 && (
        <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
          <p className="text-xs text-gray-400 dark:text-gray-500">
            Showing {rangeStart}-{rangeEnd} of {totalItems} curated drops
          </p>
          <div className="flex items-center gap-1.5">
            <button
              type="button"
              disabled={currentPage === 1}
              onClick={() => setPage(currentPage - 1)}
              className="flex h-9 items-center gap-1 rounded-full border border-gray-200 dark:border-gray-700 px-3 text-xs font-semibold text-gray-600 dark:text-gray-300 disabled:opacity-40 disabled:cursor-not-allowed hover:border-gray-300 dark:hover:border-gray-600"
            >
              <ChevronLeft size={13} /> Previous
            </button>
            {pageNumbers.map((pageNumber, index) => (
              <React.Fragment key={pageNumber}>
                {index > 0 && pageNumbers[index - 1] !== pageNumber - 1 && <span className="px-1 text-xs text-gray-400">…</span>}
                <button
                  type="button"
                  aria-current={pageNumber === currentPage ? 'page' : undefined}
                  onClick={() => setPage(pageNumber)}
                  className={`flex h-9 w-9 items-center justify-center rounded-full text-xs font-bold transition-colors ${pageNumber === currentPage ? 'bg-[#fa3f5e] text-white' : 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900'}`}
                >
                  {pageNumber}
                </button>
              </React.Fragment>
            ))}
            <button
              type="button"
              disabled={currentPage === totalPages}
              onClick={() => setPage(currentPage + 1)}
              className="flex h-9 items-center gap-1 rounded-full border border-gray-200 dark:border-gray-700 px-3 text-xs font-semibold text-gray-600 dark:text-gray-300 disabled:opacity-40 disabled:cursor-not-allowed hover:border-gray-300 dark:hover:border-gray-600"
            >
              Next <ChevronRight size={13} />
            </button>
          </div>
        </div>
      )}

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
                      <button key={filter} type="button" onClick={() => applyActiveFilter(filter)} className={`rounded-xl border px-3 py-2.5 text-xs font-semibold transition-colors ${activeFilter === filter ? 'border-[#fa3f5e] bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/10' : 'border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'}`}>{filter}</button>
                    ))}
                  </div>
                </fieldset>
                <label className="block text-xs font-bold uppercase tracking-wide text-gray-400">
                  Category
                  <select value={categoryFilter} onChange={(event) => applyCategoryFilter(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-sm font-semibold normal-case tracking-normal text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white">
                    {categories.map((category) => <option key={category} value={category}>{category}</option>)}
                  </select>
                </label>
                <div>
                  <p className="mb-2 text-xs font-bold uppercase tracking-wide text-gray-400">Price range</p>
                  <div className="grid grid-cols-2 gap-2">
                    <input type="number" min="0" value={minPrice} onChange={(event) => applyMinPrice(event.target.value)} placeholder="Min" className="h-11 rounded-xl border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white" />
                    <input type="number" min="0" value={maxPrice} onChange={(event) => applyMaxPrice(event.target.value)} placeholder="Max" className="h-11 rounded-xl border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white" />
                  </div>
                </div>
                <label className="block text-xs font-bold uppercase tracking-wide text-gray-400">
                  Sort
                  <select value={sortBy} onChange={(event) => applySortBy(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-sm font-semibold normal-case tracking-normal text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white">
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
    </div>
  );
};

export default Market;
