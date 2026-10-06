import { createSlice } from '@reduxjs/toolkit';
import { SEED_SERVICES } from '../myStore/data/mockServices';
import { defaultAvailability } from '../myStore/data/serviceFields';

// Same in-memory catalog lifecycle as Products.
const servicesSlice = createSlice({
  name: 'services',
  initialState: {
    items: SEED_SERVICES.map((service, index) => ({
      ...service, status: 'Published', visible: true, bookings: [2, 1, 2][index],
      category: ['Home Services', 'Delivery', 'Photography'][index],
      rateType: ['Starting from', 'Fixed price', 'Per session'][index],
      duration: '1 hour', method: 'At customer location', address: '', provider: '',
      images: [], highlights: [], availability: defaultAvailability(),
    })),
  },
  reducers: {
    addService: (state, { payload }) => {
      const id = state.items.reduce((max, item) => Math.max(max, item.id), 0) + 1;
      state.items.push({ ...payload, id, bookings: 0 });
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
