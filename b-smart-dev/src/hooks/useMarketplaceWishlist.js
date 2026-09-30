import { useCallback, useEffect, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  toggleWishlistItem,
  fetchWishlist,
  addWishlistItem,
  removeWishlistItem,
  clearWishlist,
} from '../store/wishlistSlice';

// Server wishlist = products (GET /wishlist et al).
// Local wishlist  = services (API is product-only, kept for backward compat).
export function useWishlist() {
  const dispatch = useDispatch();
  const isAuthenticated = useSelector((state) => state.auth.isAuthenticated);
  const items = useSelector((state) => state.wishlist.serverItems);
  const status = useSelector((state) => state.wishlist.serverStatus);
  const error = useSelector((state) => state.wishlist.serverError);
  const mutatingId = useSelector((state) => state.wishlist.mutatingId);
  const clearing = useSelector((state) => state.wishlist.clearing);

  useEffect(() => {
    if (isAuthenticated && status === 'idle') dispatch(fetchWishlist());
  }, [isAuthenticated, status, dispatch]);

  const refresh = useCallback(() => dispatch(fetchWishlist()), [dispatch]);
  const isSaved = useCallback(
    (id) => items.some((p) => String(p.id) === String(id)),
    [items],
  );
  const add = useCallback((id) => dispatch(addWishlistItem(id)), [dispatch]);
  const remove = useCallback((id) => dispatch(removeWishlistItem(id)), [dispatch]);
  const toggle = useCallback(
    (id) => dispatch(isSaved(id) ? removeWishlistItem(id) : addWishlistItem(id)),
    [dispatch, isSaved],
  );
  const clear = useCallback(() => dispatch(clearWishlist()), [dispatch]);

  return {
    items,
    count: items.length,
    loading: status === 'loading' || status === 'idle',
    status,
    error,
    mutatingId,
    clearing,
    isSaved,
    add,
    remove,
    toggle,
    clear,
    refresh,
  };
}

// Backward-compatible hook used by Market / ProductDetail / ServiceDetail.
// Products → server wishlist API only; services → local slice only (the
// wishlist API is product-only).
export default function useMarketplaceWishlist() {
  const dispatch = useDispatch();
  const user = useSelector((state) => state.auth.userObject);
  const userId = user?._id || user?.id;
  const local = useSelector((state) => (userId ? state.wishlist.byUser[String(userId)] : undefined));
  const localItems = useMemo(() => local || [], [local]);
  const server = useWishlist();

  const isSaved = useCallback(
    (type, id) => {
      if (type === 'product') return server.isSaved(id);
      return localItems.some((item) => item.type === type && item.id === String(id));
    },
    [localItems, server],
  );

  const toggle = useCallback(
    (type, id) => {
      if (type === 'product') {
        server.toggle(id);
        return;
      }
      if (userId) dispatch(toggleWishlistItem({ userId: String(userId), type, id }));
    },
    [dispatch, userId, server],
  );

  const items = [
    ...server.items.map((p) => ({ type: 'product', id: String(p.id), product: p })),
    ...localItems.filter((i) => i.type === 'service'),
  ];

  return { items, isSaved, toggle, server };
}
