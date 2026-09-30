import { createSlice } from '@reduxjs/toolkit';

// User's own listings, created via the Add Product page. Starts empty — no
// demo products. (Backend influencer-products CRUD will replace this when it
// lands; images stored here are already real uploaded fileUrls.)
const nextId = (items) => items.reduce(
  (max, p) => (typeof p.id === 'number' ? Math.max(max, p.id) : max),
  0,
) + 1;

const productsSlice = createSlice({
  name: 'products',
  initialState: {
    items: [],
  },
  reducers: {
    addProduct: (state, action) => {
      state.items.push({
        id: nextId(state.items),
        rating: 0,
        reviews: 0,
        views: 0,
        vendorRating: 0,
        vendorLocation: '',
        ...action.payload,
      });
    },
    deleteProduct: (state, action) => {
      state.items = state.items.filter((p) => p.id !== action.payload);
    },
    updateProduct: (state, action) => {
      const { id, ...changes } = action.payload;
      const product = state.items.find((p) => p.id === id);
      if (product) Object.assign(product, changes);
    },
  },
});

export const { addProduct, deleteProduct, updateProduct } = productsSlice.actions;
export default productsSlice.reducer;
