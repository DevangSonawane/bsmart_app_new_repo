import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { Heart, Star, Eye, Store, ShoppingCart, Package, UserRound, ReceiptText, Search } from 'lucide-react';
import { addItem } from '../store/cartSlice';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { servicePrice } from '../myStore/data/serviceFields';
import { getProfilePath } from '../utils/profilePath';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';

const FILTERS = ['All', 'Products', 'Services', 'Persons'];

export const ProductCard = ({ product, isFavorite, onToggleFavorite, showType = false }) => {
  const dispatch = useDispatch();
  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };

  const handleAddToCart = () => {
    dispatch(addItem({
      id: product.id,
      name: product.name,
      subtitle: product.dimensions,
      brand: product.vendor,
      price: product.price,
      category: product.category,
    }));
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
        <div className={`relative aspect-[4/3] flex items-center justify-center ${bg}`}>
          <Link to={`/market/product/${product.id}`} aria-label={`View ${product.name}`} className="absolute inset-0 flex items-center justify-center">
            <Icon size={48} className={`${text} opacity-70`} />
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
        <Link to={`/market/product/${product.id}`}>
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
            className="flex-1 py-1.5 rounded-lg text-xs font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
          >
            Add to Cart
          </button>
          <Link
            to={`/market/product/${product.id}`}
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
  const profilePath = user._id || user.id ? getProfilePath(user) : '/market/my-store/profile';
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
  const { isSaved, toggle } = useMarketplaceWishlist();
  const allProducts = useSelector((state) => state.products.items);
  const allServices = useSelector((state) => state.services.items);
  const user = useSelector((state) => state.auth.userObject);
  const cartCount = useSelector((state) => state.cart.items.reduce((sum, i) => sum + i.qty, 0));

  const query = searchQuery.trim().toLowerCase();
  const matchesQuery = (...values) => !query || values.some((value) => String(value ?? '').toLowerCase().includes(query));
  const listedProducts = allProducts.filter((item) => (item.status || (item.rating > 0 ? 'Active' : 'Draft')) === 'Active');
  const listedServices = allServices.filter((item) => item.status === 'Published' && item.visible);
  const products = listedProducts.filter((item) => matchesQuery(item.name, item.category, item.vendor, item.description));
  const services = listedServices.filter((item) => matchesQuery(item.name, item.category, item.provider, item.description, ...((item.subservices || []).map((subservice) => subservice.name))));
  const showProducts = activeFilter === 'All' || activeFilter === 'Products';
  const showServices = activeFilter === 'All' || activeFilter === 'Services';
  const showPersons = activeFilter === 'All' || activeFilter === 'Persons';
  const showCreator = !!user && (listedProducts.length > 0 || listedServices.length > 0) && matchesQuery(user.name, user.full_name, user.username);
  const hasResults = (showProducts && products.length > 0) || (showServices && services.length > 0) || (showPersons && showCreator);

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
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
          <Link
            to="/market/my-store"
            className="flex items-center gap-1.5 px-3 h-10 rounded-full border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-700"
          >
            <Store size={16} /> My Store
          </Link>
          <Link
            to="/cart"
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

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between mb-6">
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((filter) => (
            <button
              key={filter}
              type="button"
              aria-pressed={activeFilter === filter}
              onClick={() => setActiveFilter(filter)}
              className={`px-4 py-1.5 rounded-full text-sm font-semibold border transition-colors ${
                activeFilter === filter
                  ? 'bg-[#fa3f5e] text-white border-[#fa3f5e]'
                  : 'border-gray-200 dark:border-gray-800 text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-700'
              }`}
            >
              {filter}
            </button>
          ))}
        </div>
        <div className="relative w-full lg:w-auto lg:flex-1 lg:min-w-0 lg:max-w-[500px]">
          <Search size={17} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="search"
            aria-label="Search Marketplace"
            placeholder="Search Marketplace"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            className="w-full h-10 rounded-full border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 pl-10 pr-4 text-sm text-gray-900 dark:text-white placeholder:text-gray-400 focus:outline-none focus:border-[#fa3f5e]"
          />
        </div>
      </div>

      <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Featured in Market</h2>
      <p className="text-xs text-gray-400 dark:text-gray-500 mb-6">Showing local Marketplace listings — not wired to live listings yet.</p>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        {showProducts && products.map((p) => (
          <ProductCard key={p.id} product={p} isFavorite={isSaved('product', p.id)} onToggleFavorite={() => toggle('product', p.id)} />
        ))}
        {showServices && services.map((service) => (
          <ServiceCard key={`service-${service.id}`} service={service} isFavorite={isSaved('service', service.id)} onToggleFavorite={() => toggle('service', service.id)} />
        ))}
        {showPersons && showCreator && <PersonCard key={user._id || user.id || 'store-creator'} user={user} productCount={listedProducts.length} serviceCount={listedServices.length} />}
        {!hasResults && (
          <p className="col-span-full text-center text-gray-400 dark:text-gray-500 py-10">
            {query ? `No results for “${searchQuery.trim()}”.` : `No ${activeFilter === 'All' ? 'marketplace listings' : activeFilter.toLowerCase()} yet.`}
          </p>
        )}
      </div>
    </div>
  );
};

export default Market;
