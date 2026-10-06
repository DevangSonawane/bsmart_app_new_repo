import React, { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  ChevronRight, ChevronDown, Heart, Star, Minus, Plus,
  ShoppingCart, Package, Loader2, ShieldCheck,
} from 'lucide-react';
import { addItem } from '../store/cartSlice';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';
import influencerProductService from '../services/influencerProductService';
import { ProductCard } from './Market';

const AccordionRow = ({ title, children, defaultOpen = false }) => {
  const [open, setOpen] = useState(defaultOpen);
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

/* const MiniProductCard = ({ product, isFavorite, onToggleFavorite }) => {
  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };
  const image = product.images?.[0];
  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
      <div className={`relative aspect-square flex items-center justify-center ${bg}`}>
        <Link to={`/market/product/${product.id}`} aria-label={`View ${product.name}`} className="absolute inset-0 flex items-center justify-center">
          {image ? <img src={image} alt={product.name} className="w-full h-full object-cover" /> : <Icon size={36} className={`${text} opacity-70`} />}
        </Link>
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
}; */

const ProductDetail = () => {
  const { productId } = useParams();
  const location = useLocation();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { isSaved, toggle } = useMarketplaceWishlist();
  const allProducts = useSelector((state) => state.products.items);
  const user = useSelector((state) => state.auth.userObject);
  const routedProduct = location.state?.product && String(location.state.product.id) === String(productId) ? location.state.product : null;
  const fallbackProduct = routedProduct || allProducts.find((p) => String(p.id) === String(productId));
  const [apiProduct, setApiProduct] = useState(routedProduct || null);
  const [loadedProductId, setLoadedProductId] = useState(null);
  const [apiProductPool, setApiProductPool] = useState([]);
  const currentApiProduct = apiProduct && String(apiProduct.id) === String(productId) ? apiProduct : null;
  const product = currentApiProduct || fallbackProduct;
  const [qty, setQty] = useState(1);
  const [adding, setAdding] = useState(false);
  const favorite = isSaved('product', productId);
  
  const [thumbIndex, setThumbIndex] = useState(0);
  const [zoomOrigin, setZoomOrigin] = useState({ x: 50, y: 50 });

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  }, [productId]);

  useEffect(() => {
    let alive = true;
    influencerProductService.get(productId)
      .then((item) => {
        if (!alive) return;
        setApiProduct(item);
        setLoadedProductId(productId);
      })
      .catch(() => {
        if (!alive) return;
        setApiProduct(null);
        setLoadedProductId(productId);
      });
    return () => { alive = false; };
  }, [productId]);

  useEffect(() => {
    let alive = true;
    influencerProductService.list()
      .then((items) => {
        if (alive) setApiProductPool(items);
      })
      .catch(() => {
        if (alive) setApiProductPool([]);
      });
    return () => { alive = false; };
  }, []);

  if (!product && loadedProductId !== productId) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black flex flex-col items-center justify-center gap-3">
        <Loader2 size={34} className="animate-spin text-[#fa3f5e]" />
        <p className="text-sm text-gray-500 dark:text-gray-400">Loading product...</p>
      </div>
    );
  }

  if (!product) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-3">
        <p className="text-gray-500 dark:text-gray-400">Product not found.</p>
        <Link to="/market" className="text-[#fa3f5e] font-semibold text-sm">Back to Market</Link>
      </div>
    );
  }

  const { icon: Icon, text, bg } = CATEGORY_STYLE[product.category] || { icon: Package, text: 'text-[#fa3f5e]', bg: 'bg-gray-50 dark:bg-gray-800' };
  const galleryImages = product.images?.length ? product.images : [];
  const heroImage = galleryImages[thumbIndex] || galleryImages[0];
  const canUseStoreLinks = params.get('from') === 'products' && user?.role === 'influencer';
  const reviewsCount = Number(product.reviews || 0);
  const rating = Number(product.rating || 0);
  const ratingPercent = Math.min(100, Math.max(0, (rating / 5) * 100));

  const handleZoomMove = (event) => {
    const rect = event.currentTarget.getBoundingClientRect();
    setZoomOrigin({
      x: ((event.clientX - rect.left) / rect.width) * 100,
      y: ((event.clientY - rect.top) / rect.height) * 100,
    });
  };

  const addToCart = async () => {
    if (adding) return false;
    setAdding(true);
    dispatch(addItem({
      id: product.id,
      productId: product.id,
      name: product.name,
      price: product.price,
      category: product.category,
      images: product.images || [],
      image: product.images?.[0],
      qty,
      variant: product.variants?.[0] ? { color: product.variants[0].color, size: product.variants[0].size || 'One Size' } : undefined,
      storeName: product.vendor,
      storeAvatar: product.seller?.avatar_url,
      storeType: 'Influencer Store',
      selected: true,
      saved: false,
    }));
    window.setTimeout(() => setAdding(false), 250);
    return true;
  };

  const handleBuyNow = async () => {
    const ok = await addToCart();
    if (ok) navigate('/cart');
  };
  const normalizeKey = (value) => String(value || '').trim().toLowerCase();
  const productPool = apiProductPool.length ? apiProductPool : allProducts;
  const currentCategory = normalizeKey(product.category);
  const currentVendor = normalizeKey(product.vendor);
  const currentSellerId = product.seller?._id || product.seller?.id || product.user_id || product.user;
  const similarProducts = productPool
    .filter((p) => String(p.id) !== String(product.id))
    .map((p) => {
      const sameCategory = normalizeKey(p.category) === currentCategory;
      const sameVendor = normalizeKey(p.vendor) === currentVendor;
      const sellerId = p.seller?._id || p.seller?.id || p.user_id || p.user;
      const sameSeller = currentSellerId && sellerId && String(sellerId) === String(currentSellerId);
      return {
        product: p,
        score: (sameCategory ? 3 : 0) + (sameSeller ? 2 : 0) + (sameVendor ? 1 : 0),
      };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, 4)
    .map(({ product: item }) => item);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1300px] ml-auto px-4 md:px-6 pt-6">
      {/* Breadcrumb */}
      <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 mb-5">
        <Link to={canUseStoreLinks ? '/market/my-store' : '/market'} className="hover:text-[#fa3f5e]">{canUseStoreLinks ? 'My Store' : 'Marketplace'}</Link>
        <ChevronRight size={14} />
        {canUseStoreLinks && (
          <>
            <Link to="/market/my-store/products" className="hover:text-[#fa3f5e]">My Products</Link>
            <ChevronRight size={14} />
          </>
        )}
        <span>{product.category}</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1.05fr)_minmax(360px,0.95fr)] gap-5 xl:gap-8 items-start">
        {/* Gallery */}
        <div className="lg:sticky lg:top-5 min-w-0">
          <div
            className={`group relative aspect-[4/3] rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-800 flex items-center justify-center ${bg}`}
            onMouseMove={handleZoomMove}
          >
            <button
              type="button"
              aria-label={`${favorite ? 'Remove' : 'Add'} ${product.name} ${favorite ? 'from' : 'to'} wishlist`}
              aria-pressed={favorite}
              onClick={() => toggle('product', product.id, product)}
              className={`absolute top-4 right-4 w-9 h-9 rounded-full bg-white dark:bg-gray-800 shadow items-center justify-center ${canUseStoreLinks ? 'hidden' : 'flex'}`}
            >
              <Heart size={16} className={favorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-400'} />
            </button>
            {heroImage
              ? <img src={heroImage} alt={product.name} className="w-full h-full object-cover transition-transform duration-200 ease-out group-hover:scale-[1.85]" style={{ transformOrigin: `${zoomOrigin.x}% ${zoomOrigin.y}%` }} />
              : <Icon size={96} className={`${text} opacity-70`} />}
          </div>
          <div className="flex gap-3 mt-3 overflow-x-auto pb-1">
            {(galleryImages.length ? galleryImages : [0, 1, 2, 3]).map((image, i) => (
              <button
                key={i}
                onClick={() => setThumbIndex(i)}
                className={`w-16 h-16 rounded-xl overflow-hidden flex items-center justify-center flex-shrink-0 border-2 ${bg} ${
                  thumbIndex === i ? 'border-[#fa3f5e]' : 'border-transparent'
                }`}
              >
                {typeof image === 'string'
                  ? <img src={image} alt="" className="w-full h-full object-cover" />
                  : <Icon size={22} className={`${text} opacity-70`} />}
              </button>
            ))}
          </div>
        </div>

        {/* Info */}
        <div className="min-w-0 rounded-2xl border border-gray-100 bg-white p-4 shadow-sm dark:border-gray-800 dark:bg-gray-900 sm:p-5">
          <p className={`text-xs font-bold uppercase tracking-wide mb-2 ${text}`}>{product.category}</p>
          <h1 className="text-2xl lg:text-3xl font-bold leading-tight text-gray-900 dark:text-white mb-3 break-words">{product.name}</h1>
          <div className="flex flex-wrap items-center gap-3 mb-4">
            <span className="flex items-center gap-1.5">
            {Array.from({ length: 5 }).map((_, i) => (
              <Star key={i} size={16} className={i < Math.round(rating) ? 'fill-amber-400 text-amber-400' : 'text-gray-300 dark:text-gray-700'} />
            ))}
            </span>
            <span className="text-sm text-gray-500 dark:text-gray-400">{rating} ({reviewsCount} reviews)</span>
            {product.stockQuantity > 0 && <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-600 dark:bg-emerald-900/20">In stock</span>}
          </div>

          <p className="text-2xl font-bold text-gray-900 dark:text-white mb-4">
            ₹{product.price.toFixed(2)} <span className="text-sm font-normal text-gray-400">INR</span>
          </p>

          <p className="text-sm text-gray-600 dark:text-gray-300 leading-6 mb-5">
            {product.description}
          </p>

          {product.highlights?.length > 0 && (
            <ul className="grid gap-2 text-sm text-gray-600 dark:text-gray-300 mb-6">
              {product.highlights.map((h, i) => <li key={i} className="flex gap-2 leading-5"><ShieldCheck size={15} className="mt-0.5 shrink-0 text-[#fa3f5e]" />{h}</li>)}
            </ul>
          )}

          {canUseStoreLinks ? (
            <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
              <Link to="/market/my-store/products" className="flex items-center justify-center rounded-xl border border-gray-200 py-3 text-sm font-bold text-gray-800 dark:border-gray-700 dark:text-gray-200">
                Back to My Products
              </Link>
              <Link to={`/market/edit-product/${product.id}`} className="flex items-center justify-center rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange py-3 text-sm font-bold text-white">
                Edit Product
              </Link>
            </div>
          ) : (
            <>
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
                  disabled={adding}
                  className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
                >
                  {adding ? <Loader2 size={16} className="animate-spin" /> : <ShoppingCart size={16} />} Add to Cart
                </button>
                <button
                  onClick={handleBuyNow}
                  disabled={adding}
                  className="flex-1 py-3 rounded-xl text-sm font-bold border border-gray-200 dark:border-gray-700 text-gray-800 dark:text-gray-200"
                >
                  Buy Now
                </button>
              </div>
            </>
          )}

          <div className="rounded-xl border border-gray-100 dark:border-gray-800 px-3">
            {product.dimensions && (
              <AccordionRow title="Dimensions">{product.dimensions}</AccordionRow>
            )}
            <AccordionRow title="Delivery" defaultOpen>
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
      {!canUseStoreLinks && <div className="mt-10 bg-gray-50 dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-4 flex flex-wrap items-center justify-between gap-4">
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
      </div>}

      {!canUseStoreLinks && (
        <section className="mt-5 rounded-2xl border border-gray-100 bg-white p-4 shadow-sm dark:border-gray-800 dark:bg-gray-900 sm:p-5">
          <div className="flex flex-col gap-5 md:flex-row md:items-start md:justify-between">
            <div>
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">Reviews</h2>
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Customer ratings and feedback for this product.</p>
            </div>
            <div className="rounded-xl bg-gray-50 px-4 py-3 dark:bg-gray-800">
              <div className="flex items-center gap-2">
                <span className="text-3xl font-bold text-gray-900 dark:text-white">{rating.toFixed(1)}</span>
                <span className="flex items-center gap-1">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Star key={i} size={15} className={i < Math.round(rating) ? 'fill-amber-400 text-amber-400' : 'text-gray-300 dark:text-gray-700'} />
                  ))}
                </span>
              </div>
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">{reviewsCount} {reviewsCount === 1 ? 'review' : 'reviews'}</p>
            </div>
          </div>
          <div className="mt-5 grid gap-4 md:grid-cols-[180px_minmax(0,1fr)]">
            <div className="space-y-2">
              {[5, 4, 3, 2, 1].map((star) => (
                <div key={star} className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
                  <span className="w-7">{star}★</span>
                  <span className="h-2 flex-1 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
                    <span className="block h-full rounded-full bg-amber-400" style={{ width: star === Math.round(rating) ? `${ratingPercent}%` : '0%' }} />
                  </span>
                </div>
              ))}
            </div>
            <div className="rounded-xl border border-dashed border-gray-200 p-4 dark:border-gray-700">
              {reviewsCount > 0 ? (
                <p className="text-sm leading-6 text-gray-500 dark:text-gray-400">This product has {reviewsCount} customer {reviewsCount === 1 ? 'review' : 'reviews'} with an average rating of {rating.toFixed(1)} out of 5.</p>
              ) : (
                <p className="text-sm leading-6 text-gray-500 dark:text-gray-400">No written reviews yet. Ratings will appear here after customers review this product.</p>
              )}
            </div>
          </div>
        </section>
      )}

      {similarProducts.length > 0 && (
        <section className="mt-8">
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">Similar Products</h2>
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">More products from this category or seller.</p>
            </div>
            <Link to="/market" className="hidden text-sm font-semibold text-[#fa3f5e] sm:inline">Browse marketplace</Link>
          </div>
          <div className="grid grid-cols-1 min-[520px]:grid-cols-2 lg:grid-cols-4 gap-4">
            {similarProducts.map((p) => <ProductCard key={p.id} product={p} isFavorite={isSaved('product', p.id)} onToggleFavorite={() => toggle('product', p.id, p)} />)}
          </div>
        </section>
      )}
    </div>
  );
};

export default ProductDetail;
