import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  addWishlistItem,
  clearWishlist,
  fetchWishlist,
  removeWishlistItem,
} from '../store/wishlistSlice';

export default function useMarketplaceWishlist() {
  const dispatch = useDispatch();
  const user = useSelector((state) => state.auth.userObject);
  const { products, loading, error } = useSelector((state) => state.wishlist);
  const userId = user?._id || user?.id;

  useEffect(() => {
    if (userId) dispatch(fetchWishlist());
  }, [dispatch, userId]);

  const isSaved = (type, id) => (
    type === 'product' && products.some((item) => String(item.id) === String(id))
  );

  const toggle = (type, id, product = null) => {
    if (!userId || type !== 'product' || id == null) return;
    const payload = { productId: id, product };
    dispatch(isSaved(type, id) ? removeWishlistItem(payload) : addWishlistItem(payload));
  };

  return {
    items: products.map((item) => ({ type: 'product', id: String(item.id) })),
    products,
    loading,
    error,
    isSaved,
    toggle,
    clear: () => dispatch(clearWishlist()),
  };
}
