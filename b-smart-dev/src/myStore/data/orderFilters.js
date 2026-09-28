export const ORDER_TABS = ['New', 'Processing', 'Shipped', 'Completed'];
export const money = (value) => `₹${Number(value).toFixed(2)}`;
export const orderDate = (value) => new Date(`${value}T12:00:00`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
const TAB_STATUSES = { New: ['Pending'], Processing: ['Processing'], Shipped: ['Shipped'], Completed: ['Delivered', 'Cancelled'] };

export function filterOrders(orders, { tab = 'New', search = '', payment = 'All status', from = '', to = '', oldest = false } = {}) {
  const query = search.trim().toLowerCase();
  return orders.filter((order) => (TAB_STATUSES[tab] || TAB_STATUSES.New).includes(order.status)
    && (!query || `${order.id} ${order.customer} ${order.items.map((item) => item.name).join(' ')}`.toLowerCase().includes(query))
    && (payment === 'All status' || order.paymentStatus === payment)
    && (!from || order.date >= from) && (!to || order.date <= to))
    .sort((a, b) => oldest ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date));
}
