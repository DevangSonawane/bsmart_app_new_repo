import api from '../lib/api';
import { loadRazorpay } from './checkoutService';

const listingSubscriptionService = {
  loadRazorpay,
  // startTrial: true -> first charge deferred 7 days; false -> billed today.
  // Authorizes the Razorpay mandate; does NOT switch the caller's role —
  // call userService's role-switch only after the Razorpay checkout handler
  // confirms success (see InfluencerSwitchModal.jsx).
  createAccountSubscription: async (startTrial) => {
    const { data } = await api.post('/listing-subscriptions/account', { start_trial: startTrial });
    return data;
  },
  // Skips the rest of a free trial and starts billing today — opens a fresh
  // Razorpay Checkout for a new mandate (Razorpay can't reschedule an
  // existing one's first charge).
  upgradeAccountSubscription: async () => {
    const { data } = await api.post('/listing-subscriptions/account/upgrade');
    return data;
  },
  getMyAccountSubscription: async () => {
    const { data } = await api.get('/listing-subscriptions/account/me');
    return data?.subscription || null;
  },
  cancel: async (subscriptionId) => {
    const { data } = await api.post(`/listing-subscriptions/${subscriptionId}/cancel`);
    return data;
  },
};

export default listingSubscriptionService;
