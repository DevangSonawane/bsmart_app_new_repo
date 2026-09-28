// Mock, frontend-only order history — placeholder until Orders is wired to a real backend.
export const ORDER_STATUSES = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

export const MOCK_ORDERS = [
  { id: 'ORD-1042', customer: 'Ananya Rao',      productId: 1, product: 'Classic Brown Leather Tote',            qty: 1, amount: 245.0,  status: 'Delivered',  date: '2026-08-28' },
  { id: 'ORD-1043', customer: 'Karthik Menon',    productId: 2, product: 'Noise Cancelling Studio Pro Headphones', qty: 1, amount: 299.99, status: 'Shipped',    date: '2026-08-30' },
  { id: 'ORD-1044', customer: 'Priya Sharma',     productId: 3, product: 'Nordic Ceramic Vase Collection',        qty: 2, amount: 170.0,  status: 'Processing', date: '2026-09-01' },
  { id: 'ORD-1045', customer: 'Rahul Verma',      productId: 1, product: 'Classic Brown Leather Tote',            qty: 1, amount: 245.0,  status: 'Pending',    date: '2026-09-03' },
  { id: 'ORD-1046', customer: 'Sneha Iyer',       productId: 2, product: 'Noise Cancelling Studio Pro Headphones', qty: 1, amount: 299.99, status: 'Cancelled',  date: '2026-09-04' },
  { id: 'ORD-1047', customer: 'Vikram Singh',     productId: 3, product: 'Nordic Ceramic Vase Collection',        qty: 1, amount: 85.0,   status: 'Delivered',  date: '2026-09-05' },
  { id: 'ORD-1048', customer: 'Meera Nair',       productId: 1, product: 'Classic Brown Leather Tote',            qty: 1, amount: 245.0,  status: 'Shipped',    date: '2026-09-06' },
  { id: 'ORD-1049', customer: 'Arjun Reddy',      productId: 2, product: 'Noise Cancelling Studio Pro Headphones', qty: 2, amount: 599.98, status: 'Pending',    date: '2026-09-07' },
];
