import api from '../lib/api';

export const checkoutService = {
  // coinsToUse: how many wallet coins to apply toward the order total
  // (clamped server-side). Defaults to 0 — fully Razorpay unless the buyer
  // drags the payment slider.
  checkout: async ({ coinsToUse = 0, shippingAddress }) => {
    const { data } = await api.post('/orders/checkout', {
      coins_to_use: coinsToUse,
      shipping_address: shippingAddress,
    });
    return data;
  },
  verifyPayment: async (orderId, payment) => {
    const { data } = await api.post(`/orders/${orderId}/verify-payment`, {
      razorpay_order_id: payment.razorpay_order_id,
      razorpay_payment_id: payment.razorpay_payment_id,
      razorpay_signature: payment.razorpay_signature,
    });
    return data;
  },
};

export const loadRazorpay = () =>
  new Promise((resolve) => {
    if (window.Razorpay) {
      resolve(true);
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.onload = () => resolve(true);
    script.onerror = () => resolve(false);
    document.body.appendChild(script);
  });

export default checkoutService;
