import { createSlice, nanoid } from '@reduxjs/toolkit';
import { MOCK_ORDERS } from '../myStore/data/mockOrders';

export const COURIERS = ['Delhivery', 'Blue Dart', 'DTDC', 'India Post', 'Other'];
export const canShipOrder = (order) => !!order && ['Pending', 'Processing'].includes(order.status)
  && order.paymentStatus === 'Paid' && order.confirmed && order.packed
  && COURIERS.includes(order.courier) && !!order.trackingNumber.trim();

// Demo orders use the same in-memory lifecycle as the Product and Service catalogs.
const ordersSlice = createSlice({
  name: 'orders',
  initialState: { items: MOCK_ORDERS.map((order, index) => ({
    ...order,
    items: [{ productId: order.productId, name: order.product, quantity: order.qty, unitPrice: order.amount / order.qty }],
    time: ['10:24 AM', '3:15 PM', '9:42 AM'][index % 3],
    paymentStatus: order.status === 'Cancelled' ? 'Refunded' : 'Paid',
    coinsDiscount: 0,
    address: { name: order.customer, street: `${24 + index} Park Road`, city: 'Bengaluru', region: 'Karnataka', postalCode: '560001', country: 'India' },
    confirmed: ['Processing', 'Shipped', 'Delivered'].includes(order.status),
    packed: ['Shipped', 'Delivered'].includes(order.status),
    courier: ['Shipped', 'Delivered'].includes(order.status) ? 'Delhivery' : '',
    trackingNumber: ['Shipped', 'Delivered'].includes(order.status) ? `DEMO${1042 + index}` : '',
    notifyCustomer: true,
  })) },
  reducers: {
    placeOrder: {
      prepare: (order) => {
        const now = new Date();
        const date = [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0'), String(now.getDate()).padStart(2, '0')].join('-');
        return { payload: { ...order, id: `ORD-${nanoid(8)}`, date, createdAt: now.toISOString(), time: now.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' }) } };
      },
      reducer: (state, { payload }) => {
        state.items.push({ ...payload, status: 'Pending', confirmed: false, packed: false, courier: '', trackingNumber: '', notifyCustomer: true });
      },
    },
    updateOrderFulfillment: (state, { payload }) => {
      const order = state.items.find((item) => item.id === payload.id);
      if (!order || !['Pending', 'Processing'].includes(order.status)) return;
      if (typeof payload.confirmed === 'boolean') {
        order.confirmed = payload.confirmed;
        if (!payload.confirmed) order.packed = false;
      }
      if (typeof payload.packed === 'boolean') order.packed = order.confirmed && payload.packed;
      if (typeof payload.courier === 'string' && (payload.courier === '' || COURIERS.includes(payload.courier))) order.courier = payload.courier;
      if (typeof payload.trackingNumber === 'string') order.trackingNumber = payload.trackingNumber.slice(0, 80);
      if (typeof payload.notifyCustomer === 'boolean') order.notifyCustomer = payload.notifyCustomer;
      order.status = order.confirmed ? 'Processing' : 'Pending';
    },
    shipOrder: (state, { payload }) => {
      const order = state.items.find((item) => item.id === payload);
      if (canShipOrder(order)) {
        order.trackingNumber = order.trackingNumber.trim();
        order.status = 'Shipped';
      }
    },
  },
});
export const { placeOrder, updateOrderFulfillment, shipOrder } = ordersSlice.actions;
export default ordersSlice.reducer;
