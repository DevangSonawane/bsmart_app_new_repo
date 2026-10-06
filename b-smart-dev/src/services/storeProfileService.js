import api from '../lib/api';

const firstStore = (value = {}) => (
  value.store
  || value.data?.store
  || value.store_profile
  || value.data?.store_profile
  || value.data
  || value
);

const normalizeList = (value) => {
  if (Array.isArray(value)) return value.map((item) => String(item).trim()).filter(Boolean);
  if (typeof value === 'string') return value.split(',').map((item) => item.trim()).filter(Boolean);
  return [];
};

export const normalizeStoreProfile = (profile = {}) => ({
  ...profile,
  store_name: profile.store_name || profile.storeName || '',
  store_type: profile.store_type || profile.storeType || '',
  about: profile.about || profile.store_description || profile.description || '',
  service_areas: normalizeList(profile.service_areas || profile.serviceAreas),
  languages: normalizeList(profile.languages),
  trust_badges: normalizeList(profile.trust_badges || profile.trustBadges),
  followers_count: Number(profile.followers_count ?? profile.followersCount ?? 0),
  following_count: Number(profile.following_count ?? profile.followingCount ?? 0),
  is_following: Boolean(profile.is_following ?? profile.isFollowing ?? false),
  product_count: Number(profile.product_count ?? profile.productCount ?? 0),
  service_count: Number(profile.service_count ?? profile.serviceCount ?? 0),
  member_since: profile.member_since || profile.memberSince || '',
});

const storeProfileService = {
  get: async (userId) => {
    const { data } = await api.get(`/users/${userId}/store-profile`);
    return normalizeStoreProfile(firstStore(data));
  },
  update: async (payload) => {
    const { data } = await api.patch('/users/me/store-profile', payload);
    return normalizeStoreProfile(firstStore(data));
  },
};

export default storeProfileService;
