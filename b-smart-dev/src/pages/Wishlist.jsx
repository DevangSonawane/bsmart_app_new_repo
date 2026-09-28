import React from 'react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { ArrowLeft, Heart } from 'lucide-react';
import { ProductCard, ServiceCard } from './Market';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';

export default function Wishlist() {
  const { items, toggle } = useMarketplaceWishlist();
  const products = useSelector((state) => state.products.items);
  const services = useSelector((state) => state.services.items);
  const savedItems = items.map(({ type, id }) => {
    if (type === 'product') {
      const item = products.find((product) => String(product.id) === id && (product.status || (product.rating > 0 ? 'Active' : 'Draft')) === 'Active');
      return item ? { type, item } : null;
    }
    const item = services.find((service) => String(service.id) === id && service.status === 'Published' && service.visible);
    return item ? { type, item } : null;
  }).filter(Boolean);

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      <Link to="/market" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e] mb-5"><ArrowLeft size={16} />Back to Marketplace</Link>
      <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">Wishlist</h1>
      {savedItems.length === 0 ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <Heart size={36} className="mx-auto text-[#fa3f5e] mb-4" />
          <p className="text-sm text-gray-500 dark:text-gray-400">Your wishlist is empty.</p>
          <Link to="/market" className="inline-block mt-5 px-5 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Explore Marketplace</Link>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {savedItems.map(({ type, item }) => type === 'product' ? (
            <ProductCard key={`${type}-${item.id}`} product={item} showType isFavorite onToggleFavorite={() => toggle(type, item.id)} />
          ) : (
            <ServiceCard key={`${type}-${item.id}`} service={item} showType isFavorite onToggleFavorite={() => toggle(type, item.id)} />
          ))}
        </div>
      )}
    </div>
  );
}
