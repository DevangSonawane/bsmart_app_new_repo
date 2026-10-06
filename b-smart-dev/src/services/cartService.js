import api from '../lib/api';
import { normalizeInfluencerProduct } from './influencerProductService';

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  const candidates = [
    value.items, value.cart?.items, value.data?.items, value.data?.cart?.items,
    value.cartItems, value.data?.cartItems,
  ];
  return candidates.find(Array.isArray) || [];
};

const normalizeCartItem = (item = {}) => {
  const productRaw = item.product_id || item.product || item.productId || {};
  const product = typeof productRaw === 'object' ? normalizeInfluencerProduct(productRaw) : {};
  const id = product.id || item.product_id || item.productId || item.id;
  const variant = item.variant || {};
  return {
    id,
    productId: id,
    name: product.name || item.name || 'Product',
    subtitle: product.dimensions || item.subtitle || '',
    brand: product.vendor || item.brand || '',
    price: Number(product.price || item.live_price || item.price || 0),
    mrp: Number(product.mrp || item.mrp || 0),
    category: product.category || item.category || '',
    qty: Number(item.quantity ?? item.qty ?? 1),
    stockQuantity: Number(item.stock_quantity ?? product.stockQuantity ?? 0),
    images: product.images || item.images || [],
    image: product.images?.[0] || item.image,
    variant,
    selected: item.selected ?? true,
    saved: false,
    storeName: item.store_name || product.vendor,
    storeAvatar: item.store_avatar || product.seller?.avatar_url,
    storeType: 'Influencer Store',
  };
};

const fetchCart = async () => {
  const { data } = await api.get('/cart');
  return firstArray(data).map(normalizeCartItem);
};

const cartService = {
  get: fetchCart,
  addItem: async ({ productId, quantity = 1, variant }) => {
    await api.post('/cart/items', {
      product_id: productId,
      quantity,
      ...(variant ? { variant } : {}),
    });
    return fetchCart();
  },
  updateItem: async (productId, payload) => {
    await api.patch(`/cart/items/${productId}`, payload);
    return fetchCart();
  },
  removeItem: async (productId) => {
    await api.delete(`/cart/items/${productId}`);
    return fetchCart();
  },
  clear: async () => {
    await api.delete('/cart');
    return [];
  },
  syncItems: async (items = []) => {
    await api.delete('/cart');
    await Promise.all(items.map((item) => api.post('/cart/items', {
      product_id: item.productId || item.id,
      quantity: item.qty || item.quantity || 1,
      ...(item.variant ? { variant: item.variant } : {}),
    })));
    return items;
  },
};

export default cartService;
