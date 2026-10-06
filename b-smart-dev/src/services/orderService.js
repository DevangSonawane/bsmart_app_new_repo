import api from '../lib/api';

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  return [
    value.orders,
    value.data?.orders,
    value.data,
    value.items,
    value.data?.items,
  ].find(Array.isArray) || [];
};

const titleStatus = (value, fallback = 'Pending') => {
  const raw = String(value || fallback).replace(/_/g, ' ').trim().toLowerCase();
  return raw.split(' ').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
};

const normalizeItem = (item = {}) => {
  const product = item.product || item.product_id || item.productId || {};
  const productId = typeof product === 'object' ? product._id || product.id : product;
  return {
    productId: productId || item.product_id || item.productId || item.id,
    name: item.name || item.product_name || product.name || 'Product',
    quantity: Number(item.quantity ?? item.qty ?? 1),
    unitPrice: Number(item.unit_price ?? item.unitPrice ?? item.price ?? product.selling_price ?? product.price ?? 0),
    image: item.image || product.images?.[0]?.url || product.images?.[0],
    variant: item.variant || item.selected_variant || item.options || null,
  };
};

export const normalizeOrder = (order = {}) => {
  const id = order._id || order.id || order.order_id || order.orderId;
  const items = (order.items || order.line_items || order.products || []).map(normalizeItem);
  const buyer = order.buyer || order.buyer_id || order.user || order.user_id || {};
  const shipping = order.shipping_address || order.address || {};
  const status = titleStatus(order.order_status || order.status, 'Pending');
  const paymentStatus = titleStatus(order.payment_status || order.paymentStatus, status === 'Cancelled' ? 'Refunded' : 'Paid');
  const createdAt = order.createdAt || order.created_at || order.date || order.placed_at;
  const date = createdAt
    ? new Date(createdAt).toISOString().slice(0, 10)
    : new Date().toISOString().slice(0, 10);
  const amount = Number(order.total_amount ?? order.amount ?? order.total ?? order.payable_amount ?? items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0));

  return {
    ...order,
    id,
    buyerId: typeof buyer === 'object' ? buyer._id || buyer.id : buyer,
    customer: shipping.name || buyer.full_name || buyer.name || buyer.username || order.customer || 'Customer',
    items,
    productId: items[0]?.productId,
    product: items[0]?.name || 'Order',
    qty: items.reduce((sum, item) => sum + item.quantity, 0),
    amount,
    status,
    paymentStatus,
    coinsDiscount: Number(order.coins_discount ?? order.coinsDiscount ?? 0),
    date,
    createdAt,
    time: createdAt ? new Date(createdAt).toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' }) : '',
    address: {
      name: shipping.name || 'Customer',
      street: shipping.address_line1 || shipping.street || shipping.address || '',
      city: shipping.city || '',
      region: shipping.state || shipping.region || '',
      postalCode: shipping.pincode || shipping.postalCode || shipping.zip || '',
      country: shipping.country || 'India',
    },
    confirmed: ['Confirmed', 'Processing', 'Shipped', 'Delivered'].includes(status),
    packed: ['Processing', 'Shipped', 'Delivered'].includes(status),
    courier: order.courier || order.shipping?.courier || '',
    trackingNumber: order.tracking_number || order.trackingNumber || order.shipping?.tracking_number || '',
    notifyCustomer: order.notify_customer ?? true,
    orderNumber: order.order_number || id,
    buyerUsername: buyer?.username || '',
    refundFailed: !!order.refund_failed,
    refundError: order.refund_error || '',
  };
};

const orderService = {
  listBuyer: async () => {
    const { data } = await api.get('/orders');
    return firstArray(data).map(normalizeOrder);
  },
  get: async (id) => {
    const { data } = await api.get(`/orders/${id}`);
    return normalizeOrder(data?.order || data?.data?.order || data?.data || data);
  },
  cancel: async (id, reason = '') => {
    const { data } = await api.patch(`/orders/${id}/cancel`, reason ? { reason } : undefined);
    return normalizeOrder(data?.order || data?.data?.order || data?.data || data);
  },
  adminList: async (params = {}) => {
    const query = Object.fromEntries(Object.entries(params).filter(([, value]) => value !== '' && value !== undefined && value !== false));
    const { data } = await api.get('/orders/admin/all', { params: query });
    return {
      orders: firstArray(data).map(normalizeOrder),
      total: Number(data?.total ?? 0),
      totalPages: Number(data?.totalPages ?? 1),
      page: Number(data?.page ?? 1),
    };
  },
  listSeller: async () => {
    const { data } = await api.get('/orders/seller/mine');
    return firstArray(data).map(normalizeOrder);
  },
  updateStatus: async (id, status, extra = {}) => {
    const { data } = await api.patch(`/orders/${id}/status`, { order_status: String(status).toLowerCase(), ...extra });
    return normalizeOrder(data?.order || data?.data?.order || data?.data || data);
  },
};

export default orderService;
