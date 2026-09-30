import { createSlice } from '@reduxjs/toolkit';

// User's own service listings, created via the Add Service page. Starts
// empty — no demo services.
const nextId = (items) => items.reduce(
  (max, item) => (typeof item.id === 'number' ? Math.max(max, item.id) : max),
  0,
) + 1;

const servicesSlice = createSlice({
  name: 'services',
  initialState: {
    items: [],
  },
  reducers: {
    addService: (state, { payload }) => {
      state.items.push({ ...payload, id: nextId(state.items), bookings: 0 });
    },
    updateService: (state, { payload }) => {
      const service = state.items.find((item) => item.id === payload.id);
      if (service) Object.assign(service, payload);
    },
    deleteService: (state, { payload }) => { state.items = state.items.filter((item) => item.id !== payload); },
  },
});
export const { addService, updateService, deleteService } = servicesSlice.actions;
export default servicesSlice.reducer;
