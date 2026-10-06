import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Heart, Loader2, Trash2, AlertCircle } from 'lucide-react';
import { ProductCard } from './Market';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';

export default function Wishlist() {
  const { products, loading, error, toggle, clear } = useMarketplaceWishlist();

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      <Link to="/market" className="inline-flex items-center gap-2 text-sm font-semibold text-[#fa3f5e] mb-5"><ArrowLeft size={16} />Back to Marketplace</Link>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Wishlist</h1>
        {products.length > 0 && (
          <button type="button" onClick={clear} disabled={loading} className="inline-flex items-center gap-2 rounded-lg border border-red-200 px-3 py-2 text-xs font-semibold text-red-500 disabled:opacity-50 dark:border-red-900/40">
            <Trash2 size={14} /> Clear wishlist
          </button>
        )}
      </div>

      {error && (
        <div className="mb-4 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">
          <AlertCircle size={15} className="shrink-0" /> {error}
        </div>
      )}

      {loading && products.length === 0 ? (
        <div className="flex flex-col items-center py-20 text-center text-gray-400">
          <Loader2 size={28} className="mb-3 animate-spin text-[#fa3f5e]" />
          <p className="text-sm">Loading wishlist...</p>
        </div>
      ) : products.length === 0 ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <Heart size={36} className="mx-auto text-[#fa3f5e] mb-4" />
          <p className="text-sm text-gray-500 dark:text-gray-400">Your wishlist is empty.</p>
          <Link to="/market" className="inline-block mt-5 px-5 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">Explore Marketplace</Link>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {products.map((product) => (
            <ProductCard key={product.id} product={product} showType isFavorite onToggleFavorite={() => toggle('product', product.id)} />
          ))}
        </div>
      )}
    </div>
  );
}
