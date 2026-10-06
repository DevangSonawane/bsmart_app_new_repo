import api from '../lib/api';
import { loadRazorpay } from './checkoutService';

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  return [
    value.bookings,
    value.service_bookings,
    value.data?.bookings,
    value.data?.service_bookings,
    value.data,
    value.items,
    value.data?.items,
  ].find(Array.isArray) || [];
};

const titleStatus = (value, fallback = 'New') => {
  const raw = String(value || fallback).replace(/_/g, ' ').trim().toLowerCase();
  if (raw === 'pending') return 'New';
  return raw.split(' ').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
};

const statusToApi = (status) => String(status || '').trim().toLowerCase().replace(/\s+/g, '_');

export const normalizeServiceBooking = (booking = {}) => {
  const id = booking._id || booking.id || booking.booking_id || booking.bookingId;
  const service = booking.service || booking.service_id || booking.serviceId || {};
  const serviceId = typeof service === 'object' ? service._id || service.id : service;
  const customer = booking.customer || booking.customer_id || booking.user || booking.user_id || {};
  const address = booking.customer_address || booking.address || {};
  const date = booking.booking_date || booking.date || booking.scheduled_date || '';
  const slot = booking.time_slot || {};
  const start = slot.start || booking.start_time || booking.time || '';
  const end = slot.end || booking.end_time || '';
  const status = titleStatus(booking.booking_status || booking.status);
  const paymentStatus = titleStatus(booking.payment_status || booking.paymentStatus, ['Confirmed', 'In Progress', 'Completed'].includes(status) ? 'Paid' : 'Pending');

  return {
    ...booking,
    id,
    serviceId,
    service: booking.service_name || service.name || booking.service || 'Service',
    customerId: typeof customer === 'object' ? customer._id || customer.id : customer,
    customer: address.name || customer.full_name || customer.name || customer.username || booking.customer || 'Customer',
    date,
    time: end ? `${start}-${end}` : start,
    timeSlot: { start, end },
    amount: Number(booking.amount ?? booking.total_amount ?? booking.price ?? service.price ?? 0),
    status,
    paymentStatus,
    paymentSecured: ['Paid', 'Confirmed'].includes(paymentStatus) || ['Confirmed', 'In Progress', 'Completed'].includes(status),
    address: [address.address_line1 || address.street || address.address, address.city, address.state, address.pincode].filter(Boolean).join(', ') || 'Online',
    note: booking.note || booking.customer_note || '',
    verified: Boolean(customer.is_verified || booking.verified),
    requestedAt: booking.createdAt || booking.created_at || booking.requestedAt || date,
    selectedSubservices: booking.selected_subservices || booking.selectedSubservices || [],
  };
};

const unwrapBooking = (data) => normalizeServiceBooking(data?.booking || data?.service_booking || data?.data?.booking || data?.data?.service_booking || data?.data || data);

const serviceBookingService = {
  loadRazorpay,
  create: async (payload) => {
    const { data } = await api.post('/service-bookings', payload);
    return data;
  },
  verifyPayment: async (bookingId, payment) => {
    const { data } = await api.post(`/service-bookings/${bookingId}/verify-payment`, {
      razorpay_order_id: payment.razorpay_order_id,
      razorpay_payment_id: payment.razorpay_payment_id,
      razorpay_signature: payment.razorpay_signature,
    });
    return data;
  },
  listBuyer: async () => {
    const { data } = await api.get('/service-bookings');
    return firstArray(data).map(normalizeServiceBooking);
  },
  get: async (id) => {
    const { data } = await api.get(`/service-bookings/${id}`);
    return unwrapBooking(data);
  },
  cancel: async (id) => {
    const { data } = await api.patch(`/service-bookings/${id}/cancel`);
    return unwrapBooking(data);
  },
  listSeller: async () => {
    const { data } = await api.get('/service-bookings/seller/mine');
    return firstArray(data).map(normalizeServiceBooking);
  },
  updateStatus: async (id, status) => {
    const { data } = await api.patch(`/service-bookings/${id}/status`, { status: statusToApi(status) });
    return unwrapBooking(data);
  },
};

export default serviceBookingService;
