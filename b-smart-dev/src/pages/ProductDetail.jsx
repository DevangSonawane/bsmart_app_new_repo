import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  ChevronRight, ChevronDown, Heart, Star, Minus, Plus,
  ShoppingCart, Package,
} from 'lucide-react';
import { addItem } from '../store/cartSlice';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';

const AccordionRow = ({ title, children }) => {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-gray-100 dark:border-gray-800">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between py-3.5 text-left text-sm font-medium text-gray-800 dark:text-gray-200"
      >
        {title}
        <ChevronDown size={16} className={`text-gray-400 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && <p className="pb-3.5 text-sm text-gray-500 dark:text-gray-400">{children}</p>}
    </div>
  );
};

const MiniProductCard = ({ product, isFavorite, onToggleFavorite }) => {
  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };
  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
      <div className={`relative aspect-square flex items-center justify-center ${bg}`}>
        <Link to={`/market/product/${product.id}`} aria-label={`View ${product.name}`} className="absolute inset-0 flex items-center justify-center"><Icon size={36} className={`${text} opacity-70`} /></Link>
        <button
          type="button"
          aria-label={`${isFavorite ? 'Remove' : 'Add'} ${product.name} ${isFavorite ? 'from' : 'to'} wishlist`}
          aria-pressed={isFavorite}
          onClick={onToggleFavorite}
          className="absolute top-2.5 right-2.5 w-6 h-6 rounded-full bg-white dark:bg-gray-800 shadow flex items-center justify-center"
        >
          <Heart size={12} className={isFavorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-400'} />
        </button>
      </div>
      <Link to={`/market/product/${product.id}`} className="block p-3">
        <p className="text-sm text-gray-900 dark:text-white font-medium truncate">{product.name}</p>
        <p className="text-sm font-bold text-gray-900 dark:text-white mt-0.5">₹{product.price.toFixed(2)}</p>
      </Link>
    </div>
  );
};

const ProductDetail = () => {
  const { productId } = useParams();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { isSaved, toggle } = useMarketplaceWishlist();
  const allProducts = useSelector((state) => state.products.items);
  const product = allProducts.find((p) => String(p.id) === String(productId));
  const [qty, setQty] = useState(1);
  const favorite = isSaved('product', productId);
  
  const [thumbIndex, setThumbIndex] = useState(0);

  if (!product) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-3">
        <p className="text-gray-500 dark:text-gray-400">Product not found.</p>
        <Link to="/market" className="text-[#fa3f5e] font-semibold text-sm">Back to Market</Link>
      </div>
    );
  }

  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };

  const addToCart = () => dispatch(addItem({
    id: product.id,
    name: product.name,
    subtitle: product.dimensions,
    brand: product.vendor,
    price: product.price,
    category: product.category,
    qty,
  }));

  const handleBuyNow = () => {
    addToCart();
    navigate('/cart');
  };
  const related = allProducts.filter((p) => p.vendor === product.vendor && p.id !== product.id).slice(0, 4);

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 pt-6">
      {/* Breadcrumb */}
      <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 mb-5">
        <Link to="/market" className="hover:text-[#fa3f5e]">Marketplace</Link>
        <ChevronRight size={14} />
        <span>{product.category}</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
        {/* Gallery */}
        <div>
          <div className={`relative aspect-[4/3] rounded-2xl flex items-center justify-center ${bg}`}>
            <button
              type="button"
              aria-label={`${favorite ? 'Remove' : 'Add'} ${product.name} ${favorite ? 'from' : 'to'} wishlist`}
              aria-pressed={favorite}
              onClick={() => toggle('product', product.id)}
              className="absolute top-4 right-4 w-9 h-9 rounded-full bg-white dark:bg-gray-800 shadow flex items-center justify-center"
            >
              <Heart size={16} className={favorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-400'} />
            </button>
            <Icon size={96} className={`${text} opacity-70`} />
          </div>
          <div className="flex gap-3 mt-3">
            {[0, 1, 2, 3].map((i) => (
              <button
                key={i}
                onClick={() => setThumbIndex(i)}
                className={`w-16 h-16 rounded-xl flex items-center justify-center flex-shrink-0 border-2 ${bg} ${
                  thumbIndex === i ? 'border-[#fa3f5e]' : 'border-transparent'
                }`}
              >
                <Icon size={22} className={`${text} opacity-70`} />
              </button>
            ))}
          </div>
          <p className="text-xs text-gray-400 dark:text-gray-500 mt-3">Showing mock data — not wired to a real product catalog yet.</p>
        </div>

        {/* Info */}
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">{product.name}</h1>
          <div className="flex items-center gap-1.5 mb-3">
            {Array.from({ length: 5 }).map((_, i) => (
              <Star key={i} size={16} className={i < Math.round(product.rating) ? 'fill-amber-400 text-amber-400' : 'text-gray-300 dark:text-gray-700'} />
            ))}
            <span className="text-sm text-gray-500 dark:text-gray-400 ml-1">{product.rating} ({product.reviews} reviews)</span>
          </div>

          <p className="text-xl font-bold text-gray-900 dark:text-white mb-4">
            ₹{product.price.toFixed(2)} <span className="text-sm font-normal text-gray-400">INR</span>
          </p>

          <p className="text-sm text-gray-600 dark:text-gray-300 leading-relaxed mb-6">
            {product.description}
          </p>

          {product.highlights?.length > 0 && (
            <ul className="text-sm text-gray-600 dark:text-gray-300 space-y-1.5 mb-6 list-disc list-inside">
              {product.highlights.map((h, i) => <li key={i}>{h}</li>)}
            </ul>
          )}

          <div className="flex items-center gap-3 mb-5">
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Quantity</span>
            <div className="flex items-center border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
              <button onClick={() => setQty((q) => Math.max(1, q - 1))} className="w-8 h-8 flex items-center justify-center text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800">
                <Minus size={14} />
              </button>
              <span className="w-8 text-center text-sm font-semibold text-gray-900 dark:text-white">{qty}</span>
              <button onClick={() => setQty((q) => q + 1)} className="w-8 h-8 flex items-center justify-center text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800">
                <Plus size={14} />
              </button>
            </div>
          </div>

          <div className="flex gap-3 mb-6">
            <button
              onClick={addToCart}
              className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
            >
              <ShoppingCart size={16} /> Add to Cart
            </button>
            <button
              onClick={handleBuyNow}
              className="flex-1 py-3 rounded-xl text-sm font-bold border border-gray-200 dark:border-gray-700 text-gray-800 dark:text-gray-200"
            >
              Buy Now
            </button>
          </div>

          <div>
            {product.dimensions && (
              <AccordionRow title="Dimensions">{product.dimensions}</AccordionRow>
            )}
            <AccordionRow title="Delivery">
              {product.dispatchTime ? `Dispatched in ${product.dispatchTime}. ` : 'Ships in 1-2 business days. '}
              {product.countryOfOrigin && `Made in ${product.countryOfOrigin}.`}
            </AccordionRow>
            <AccordionRow title="Return Policy">
              {product.returnPolicy || '7 Days Replacement'}
            </AccordionRow>
            {product.warranty && product.warranty !== 'None' && (
              <AccordionRow title="Warranty">{product.warranty}</AccordionRow>
            )}
          </div>
        </div>
      </div>

      {/* Seller bar */}
      <div className="mt-10 bg-gray-50 dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-4 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center font-bold text-gray-600 dark:text-gray-300">
            {product.vendor.charAt(0)}
          </div>
          <div>
            <p className="font-semibold text-gray-900 dark:text-white text-sm">Sold by {product.vendor}</p>
            <p className="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-1">
              <Star size={11} className="fill-amber-400 text-amber-400" /> {product.vendorRating} Vendor Rating
              <span className="mx-1">·</span> {product.vendorLocation}
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <button className="px-4 py-2 rounded-lg text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300">
            View Store
          </button>
          <button className="px-4 py-2 rounded-lg text-xs font-bold text-white bg-[#fa3f5e]">
            Follow
          </button>
        </div>
      </div>

      {/* Related */}
      {related.length > 0 && (
        <div className="mt-10">
          <h2 className="text-lg font-bold text-gray-900 dark:text-white mb-4">More from this seller</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {related.map((p) => <MiniProductCard key={p.id} product={p} isFavorite={isSaved('product', p.id)} onToggleFavorite={() => toggle('product', p.id)} />)}
          </div>
        </div>
      )}
    </div>
  );
};

export default ProductDetail;
