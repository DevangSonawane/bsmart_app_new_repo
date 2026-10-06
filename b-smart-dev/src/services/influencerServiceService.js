import api from '../lib/api';
import { resolveProductImageUrl, normalizeUploadPath } from './influencerProductService';

// Uploads all files in a single multipart request — one round trip instead of
// one request per image. Returns results in the same order the files were given.
const uploadInfluencerServiceImages = async (files) => {
  if (!files.length) return [];
  const formData = new FormData();
  files.forEach((file) => formData.append('files', file));
  const { data } = await api.post('/upload/influencer-service', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return (data.images || []).map((img) => ({
    fileName: normalizeUploadPath(img.fileName || img.fileUrl),
  }));
};

const prepareServiceImages = async (images) => {
  const newFiles = images.filter((img) => img.file).map((img) => img.file);
  const uploaded = await uploadInfluencerServiceImages(newFiles);
  let uploadIndex = 0;
  return images.map((img) => (
    img.file ? uploaded[uploadIndex++] : { fileName: normalizeUploadPath(img.fileName || img.url) }
  ));
};

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const RATE_TO_API = {
  'Starting from': 'starting_from',
  'Fixed price': 'fixed',
  'Per hour': 'per_hour',
  'Per session': 'per_session',
};

const RATE_FROM_API = {
  starting_from: 'Starting from',
  fixed: 'Fixed price',
  per_hour: 'Per hour',
  per_session: 'Per session',
};

const METHOD_TO_API = {
  'At customer location': 'at_customer_location',
  Online: 'online',
  'At my location': 'at_my_location',
};

const METHOD_FROM_API = {
  at_customer_location: 'At customer location',
  online: 'Online',
  at_my_location: 'At my location',
};

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  const candidates = [
    value.data, value.services, value.items, value.results,
    value.data?.services, value.data?.items, value.data?.results,
  ];
  return candidates.find(Array.isArray) || [];
};

const availabilityFromApi = (value = {}) => {
  if (Array.isArray(value)) return value;
  return DAYS.map((day) => ({
    day,
    slots: Array.isArray(value[day.toLowerCase()]) ? value[day.toLowerCase()] : [],
  }));
};

const availabilityToApi = (availability = []) => DAYS.reduce((acc, day) => {
  const entry = availability.find((item) => item.day === day);
  acc[day.toLowerCase()] = (entry?.slots || [])
    .filter((slot) => slot.start && slot.end)
    .map((slot) => ({ start: slot.start, end: slot.end }));
  return acc;
}, {});

export const normalizeInfluencerService = (service = {}) => {
  const id = service._id || service.id;
  const seller = service.user_id || service.user || service.influencer || service.owner || {};
  const sellerProfile = service.influencer_profile || seller.influencer_profile || {};
  return {
    ...service,
    id,
    images: Array.isArray(service.images) ? service.images.map(resolveProductImageUrl).filter(Boolean) : [],
    name: service.name || '',
    category: service.category || 'Other',
    provider: service.provider || sellerProfile.store_name || seller.full_name || seller.username || '',
    description: service.short_description || service.description || '',
    highlights: service.key_highlights || service.highlights || [],
    price: Number(service.price || 0),
    rateType: RATE_FROM_API[service.rate_type] || service.rateType || 'Starting from',
    duration: service.duration || '1 hour',
    subservices: (service.subservices || []).map((item, index) => ({
      id: item.id || item._id || `${id || 'sub'}-${index}`,
      name: item.name || '',
      hours: item.hours ?? '',
      price: item.price ?? '',
    })),
    method: METHOD_FROM_API[service.service_method] || service.method || 'At customer location',
    availability: availabilityFromApi(service.weekly_availability || service.availability),
    visible: service.visible_to_customers ?? service.visible ?? true,
    status: service.status === 'draft' || service.status === 'Draft' ? 'Draft' : 'Published',
    bookings: Number(service.bookings || service.bookings_count || 0),
    rating: Number(service.rating || 0),
    reviews: Number(service.reviews || service.reviews_count || 0),
    providerAvatar: resolveProductImageUrl(seller.avatar_url || seller.profile_picture || ''),
    providerVerified: Boolean(seller.is_verified || sellerProfile.validated),
    seller,
  };
};

export const serviceFormToApiPayload = ({ form, highlights, subservices, availability, images, draft }) => ({
  images,
  name: form.name.trim(),
  category: form.category,
  provider: form.provider.trim(),
  short_description: form.description.trim(),
  key_highlights: highlights.map((item) => item.trim()).filter(Boolean),
  price: Number(form.price) || 0,
  rate_type: RATE_TO_API[form.rateType] || 'starting_from',
  duration: form.duration,
  subservices: subservices.map((item) => ({
    name: item.name.trim(),
    hours: Number(item.hours) || 0,
    price: Number(item.price) || 0,
  })),
  service_method: METHOD_TO_API[form.method] || 'at_customer_location',
  weekly_availability: availabilityToApi(availability),
  visible_to_customers: Boolean(form.visible),
  status: draft ? 'draft' : 'active',
});

const influencerServiceService = {
  prepareImages: prepareServiceImages,
  list: async (params = {}) => {
    const { data } = await api.get('/influencer-services', { params });
    return firstArray(data).map(normalizeInfluencerService);
  },
  listMine: async () => {
    const { data } = await api.get('/influencer-services/my');
    return firstArray(data).map(normalizeInfluencerService);
  },
  get: async (id) => {
    const { data } = await api.get(`/influencer-services/${id}`);
    return normalizeInfluencerService(data.service || data.data || data);
  },
  create: async (payload) => {
    const { data } = await api.post('/influencer-services', payload);
    return normalizeInfluencerService(data.service || data.data || data);
  },
  update: async (id, payload) => {
    const { data } = await api.patch(`/influencer-services/${id}`, payload);
    return normalizeInfluencerService(data.service || data.data || data);
  },
  remove: async (id) => api.delete(`/influencer-services/${id}`),
};

export default influencerServiceService;
