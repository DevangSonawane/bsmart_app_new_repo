import api from '../lib/api';

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  return [
    value.addresses,
    value.data?.addresses,
    value.items,
    value.data?.items,
    value.data,
  ].find(Array.isArray) || [];
};

export const normalizeAddress = (address = {}) => ({
  ...address,
  id: address._id || address.id,
  label: address.label || 'Address',
  name: address.name || '',
  phone: address.phone || '',
  address_line1: address.address_line1 || address.addressLine1 || address.street || address.address || '',
  city: address.city || '',
  state: address.state || '',
  pincode: address.pincode || address.zip || address.postalCode || '',
  is_default: Boolean(address.is_default ?? address.isDefault ?? address.default),
});

const unwrapAddress = (data) => normalizeAddress(data?.address || data?.data?.address || data?.data || data);

const addressPayload = (address) => ({
  label: String(address.label || '').trim(),
  name: String(address.name || '').trim(),
  phone: String(address.phone || '').trim(),
  address_line1: String(address.address_line1 || '').trim(),
  city: String(address.city || '').trim(),
  state: String(address.state || '').trim(),
  pincode: String(address.pincode || '').trim(),
});

const addressService = {
  list: async () => {
    const { data } = await api.get('/addresses');
    return firstArray(data).map(normalizeAddress);
  },
  create: async (address) => {
    const { data } = await api.post('/addresses', addressPayload(address));
    return unwrapAddress(data);
  },
  update: async (id, address) => {
    const { data } = await api.patch(`/addresses/${id}`, addressPayload(address));
    return unwrapAddress(data);
  },
  remove: async (id) => {
    await api.delete(`/addresses/${id}`);
  },
  setDefault: async (id) => {
    const { data } = await api.patch(`/addresses/${id}/default`);
    return unwrapAddress(data);
  },
};

export default addressService;
