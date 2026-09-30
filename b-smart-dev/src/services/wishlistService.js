import api from '../lib/api';

// ── Wishlist API ─────────────────────────────────────────────────────────────
// Backend routes (auth required, Bearer token attached by api interceptor):
//   GET    /wishlist              → logged-in user's wishlist (full product data, newest first)
//   DELETE /wishlist              → clear entire wishlist
//   POST   /wishlist/items        → { product_id } — add (no-op if already there)
//   DELETE /wishlist/items/:id    → remove one product

const pickArray = (payload) => {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== 'object') return [];
  for (const key of ['wishlist', 'items', 'products', 'data', 'results']) {
    if (Array.isArray(payload[key])) return payload[key];
  }
  // { data: { wishlist: [...] } } shape
  if (payload.data && typeof payload.data === 'object') {
    for (const key of ['wishlist', 'items', 'products', 'results']) {
      if (Array.isArray(payload.data[key])) return payload.data[key];
    }
  }
  return [];
};

// Normalize any backend product shape into the card-friendly shape used by
// Market / ProductDetail / Wishlist UI. Never throws — falls back gracefully.
export const normalizeWishlistProduct = (raw, index = 0) => {
  if (!raw || typeof raw !== 'object') return null;
  // Backend may wrap: { product: {...}, added_at } or return the product flat
  const p = raw.product && typeof raw.product === 'object' ? { ...raw.product, _wishMeta: raw } : raw;
  const id = p.id ?? p._id ?? p.product_id ?? p.productId ?? raw.product_id ?? raw.productId;
  if (id == null || id === '') return null;
  const images = Array.isArray(p.images) && p.images.length
    ? p.images
    : [p.image, p.thumbnail, p.cover, p.photo, p.image_url, p.imageUrl].filter(Boolean);
  const priceNum = Number(p.price ?? p.amount ?? p.unitPrice ?? 0);
  return {
    id: String(id),
    rawId: id,
    name: p.name ?? p.title ?? p.product_name ?? 'Untitled product',
    category: p.category ?? p.category_name ?? 'General',
    vendor: p.vendor ?? p.store ?? p.seller ?? p.brand ?? p.shop_name ?? '',
    price: Number.isFinite(priceNum) ? priceNum : 0,
    originalPrice: p.original_price ?? p.mrp ?? p.compare_at_price ?? null,
    rating: Number(p.rating ?? p.avg_rating ?? 0) || 0,
    reviews: Number(p.reviews ?? p.review_count ?? p.total_reviews ?? 0) || 0,
    views: Number(p.views ?? 0) || 0,
    description: p.description ?? p.details ?? '',
    images,
    image: images[0] ?? null,
    dimensions: p.dimensions ?? '',
    status: p.status ?? 'Active',
    addedAt: raw.added_at ?? raw.created_at ?? raw.addedAt ?? p.added_at ?? null,
    _index: index,
    _raw: p,
  };
};

export const normalizeWishlist = (payload) => pickArray(payload)
  .map(normalizeWishlistProduct)
  .filter(Boolean);

const wishlistService = {
  async getWishlist() {
    const res = await api.get('/wishlist');
    return normalizeWishlist(res?.data);
  },

  async addItem(productId) {
    const res = await api.post('/wishlist/items', { product_id: String(productId) });
    // POST returns updated wishlist — use it when present
    const list = normalizeWishlist(res?.data);
    // Some backends return { success: true } only; fall back to refetch
    if (list.length || Array.isArray(res?.data)) return list;
    return null;
  },

  async removeItem(productId) {
    const res = await api.delete(`/wishlist/items/${encodeURIComponent(String(productId))}`);
    const list = normalizeWishlist(res?.data);
    if (list.length || Array.isArray(res?.data)) return list;
    return null;
  },

  async clear() {
    await api.delete('/wishlist');
    return [];
  },
};

export default wishlistService;
