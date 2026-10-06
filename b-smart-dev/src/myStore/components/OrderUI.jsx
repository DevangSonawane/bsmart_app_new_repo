import React from 'react';
import { Package, ShoppingBag, Headphones, Flower2 } from 'lucide-react';

export function OrderProductImage({ item, products, className = 'w-11 h-11' }) {
  const product = products.find((entry) => entry.id === item.productId);
  const Icon = { Fashion: ShoppingBag, Tech: Headphones, Home: Flower2 }[product?.category] || Package;
  return (
    <div className={`${className} flex-shrink-0 rounded-lg overflow-hidden bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center border border-pink-100 dark:border-gray-800`}>
      {product?.images?.[0] ? <img src={product.images[0]} alt={item.name} className="w-full h-full object-cover" /> : <Icon size={21} className="text-[#fa3f5e]" />}
    </div>
  );
}

export function PaymentBadge({ status }) {
  const style = status === 'Paid' ? 'bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400' : status === 'Refunded' ? 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400' : 'bg-amber-50 dark:bg-amber-900/20 text-amber-600';
  return <span className={`inline-flex rounded-md px-2.5 py-1 text-[11px] font-semibold ${style}`}>{status}</span>;
}

const ORDER_STATUS_STYLE = {
  Pending: 'bg-amber-50 dark:bg-amber-900/20 text-amber-600 dark:text-amber-400',
  Confirmed: 'bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400',
  Processing: 'bg-indigo-50 dark:bg-indigo-900/20 text-indigo-600 dark:text-indigo-400',
  Shipped: 'bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400',
  Delivered: 'bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400',
  Cancelled: 'bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400',
};

export function StatusBadge({ status }) {
  const style = ORDER_STATUS_STYLE[status] || 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400';
  return <span className={`inline-flex rounded-md px-2.5 py-1 text-[11px] font-semibold whitespace-nowrap ${style}`}>{status}</span>;
}
