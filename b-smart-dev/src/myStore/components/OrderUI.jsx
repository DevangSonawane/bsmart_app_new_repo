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
