import { useDispatch, useSelector } from 'react-redux';
import { toggleWishlistItem } from '../store/wishlistSlice';

export default function useMarketplaceWishlist() {
  const dispatch = useDispatch();
  const user = useSelector((state) => state.auth.userObject);
  const userId = user?._id || user?.id;
  const saved = useSelector((state) => userId ? state.wishlist.byUser[String(userId)] : undefined);
  const items = saved || [];

  return {
    items,
    isSaved: (type, id) => items.some((item) => item.type === type && item.id === String(id)),
    toggle: (type, id) => {
      if (userId) dispatch(toggleWishlistItem({ userId: String(userId), type, id }));
    },
  };
}
