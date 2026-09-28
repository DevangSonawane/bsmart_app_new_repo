import { createSlice, nanoid } from '@reduxjs/toolkit';
import { MOCK_BOOKINGS } from '../myStore/data/mockBookings';
import { localDate, validProposal } from '../myStore/data/bookingHelpers';

// Frontend demo data, matching the store's other catalogs.
const bookingsSlice = createSlice({
  name: 'bookings',
  initialState: { items: MOCK_BOOKINGS.map((booking, index) => ({
    ...booking,
    date: booking.status === 'Confirmed' ? localDate() : booking.date,
    amount: booking.service === 'Photography Session' ? 60 : booking.service === 'Home Delivery' ? 10 : 25,
    address: `${24 + index} Market Street, Bengaluru, Karnataka 560001`,
    note: ['Please call when you arrive.', 'Please bring the equipment needed for installation.', 'Please leave the delivery at the reception.'][index % 3],
    verified: true, paymentSecured: true, proposedDate: '', proposedTime: '',
  })) },
  reducers: {
    requestBooking: {
      prepare: (booking) => ({ payload: { ...booking, id: `BK-${nanoid(8)}` } }),
      reducer: (state, { payload }) => {
        state.items.push({ ...payload, status: 'New', verified: false, paymentSecured: false, proposedDate: '', proposedTime: '' });
      },
    },
    acceptBooking: (state, { payload }) => {
      const booking = state.items.find((item) => item.id === payload);
      if (booking?.status === 'New') booking.status = 'Confirmed';
    },
    declineBooking: (state, { payload }) => {
      const booking = state.items.find((item) => item.id === payload);
      if (booking && ['New', 'Proposed'].includes(booking.status)) booking.status = 'Declined';
    },
    proposeBookingTime: {
      prepare: (payload) => ({ payload: { ...payload, valid: validProposal(payload.date, payload.time) } }),
      reducer: (state, { payload }) => {
        const booking = state.items.find((item) => item.id === payload.id);
        if (!booking || !['New', 'Proposed'].includes(booking.status) || !payload.valid) return;
        booking.proposedDate = payload.date;
        booking.proposedTime = payload.time;
        booking.status = 'Proposed';
      },
    },
    completeBooking: (state, { payload }) => {
      const booking = state.items.find((item) => item.id === payload);
      if (booking?.status === 'Confirmed') booking.status = 'Completed';
    },
  },
});
export const { acceptBooking, declineBooking, proposeBookingTime, completeBooking, requestBooking } = bookingsSlice.actions;
export default bookingsSlice.reducer;
