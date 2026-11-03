import api from '../lib/api';
import { normalizeInfluencerProduct } from './influencerProductService';

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  const candidates = [
    value.products, value.data?.products, value.items, value.data?.items,
  ];
  return candidates.find(Array.isArray) || [];
};

const wishlistService = {
  list: async () => {
    const { data } = await api.get('/wishlist');
    return firstArray(data).map((item) => ({
      ...normalizeInfluencerProduct(item),
      wishlistedAt: item.wishlisted_at || item.wishlistedAt || '',
    }));
  },
  addItem: async (productId) => {
    await api.post('/wishlist/items', { product_id: productId });
    return { productId };
  },
  removeItem: async (productId) => {
    await api.delete(`/wishlist/items/${productId}`);
    return { productId };
  },
  clear: async () => {
    await api.delete('/wishlist');
    return [];
  },
};

export default wishlistService;
