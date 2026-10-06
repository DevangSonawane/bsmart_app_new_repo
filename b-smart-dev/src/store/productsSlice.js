import { createSlice } from '@reduxjs/toolkit';
import { MOCK_PRODUCTS } from '../data/mockProducts';

// Mock, frontend-only product catalog — seeded from mockProducts.js and
// extended in-memory when a product is added via the Add Product page.
const productsSlice = createSlice({
  name: 'products',
  initialState: {
    items: MOCK_PRODUCTS,
  },
  reducers: {
    addProduct: (state, action) => {
      const nextId = state.items.reduce((max, p) => Math.max(max, p.id), 0) + 1;
      state.items.push({
        id: nextId,
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
