import api from '../lib/api';

const API_ORIGIN = (api.defaults.baseURL || 'https://bsmart-backend-dev.bsmart.workers.dev/api').replace(/\/api\/?$/, '');

const firstArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  const candidates = [
    value.data, value.products, value.items, value.results,
    value.data?.products, value.data?.items, value.data?.results,
  ];
  return candidates.find(Array.isArray) || [];
};

export const normalizeUploadPath = (value) => {
  if (!value) return '';
  const str = String(value);
  if (/^https?:\/\//i.test(str)) {
    const marker = '/uploads/';
    const idx = str.indexOf(marker);
    return idx >= 0 ? `uploads/${str.slice(idx + marker.length)}` : str;
  }
  const clean = str.replace(/^\/+/, '');
  return clean.startsWith('uploads/') ? clean : `uploads/${clean}`;
};

export const resolveProductImageUrl = (value) => {
  if (!value) return '';
  const raw = typeof value === 'string'
    ? value
    : value.fileUrl || value.url || value.fileName || value.filename || value.path || '';
  if (!raw) return '';
  if (/^https?:\/\//i.test(raw)) return raw;
  const clean = String(raw).replace(/^\/+/, '');
  return clean.startsWith('uploads/') ? `${API_ORIGIN}/${clean}` : `${API_ORIGIN}/uploads/${clean}`;
};

const normalizeStatus = (status) => {
  const value = String(status || '').toLowerCase();
  if (value === 'active' || value === 'published') return 'Active';
  if (value === 'out_of_stock' || value === 'out of stock') return 'Out of Stock';
  return 'Draft';
};

const apiStatus = (status) => {
  const value = String(status || '').toLowerCase();
  if (value === 'active') return 'active';
  if (value === 'out of stock' || value === 'out_of_stock') return 'out_of_stock';
  return 'draft';
};

export const normalizeInfluencerProduct = (product = {}) => {
  const id = product._id || product.id;
  const images = Array.isArray(product.images) ? product.images.map(resolveProductImageUrl).filter(Boolean) : [];
  const dimensions = product.dimensions && typeof product.dimensions === 'object' ? product.dimensions : {};
  const seller = product.user_id || product.user || product.influencer || product.owner || {};
  const sellerProfile = product.influencer_profile || seller.influencer_profile || {};
  return {
    ...product,
    id,
    images,
    name: product.name || '',
    vendor: product.brand || sellerProfile.store_name || seller.full_name || seller.username || 'Influencer',
    category: product.category || 'Fashion',
    description: product.short_description || product.description || '',
    price: Number(product.selling_price ?? product.price ?? 0),
    mrp: Number(product.mrp ?? product.selling_price ?? product.price ?? 0),
    stockQuantity: Number(product.stock_quantity ?? product.stockQuantity ?? 0),
    sku: product.seller_sku || product.sku || '',
    trackInventory: product.track_inventory ?? product.trackInventory ?? true,
    status: normalizeStatus(product.status),
    packageWeight: product.package_weight != null ? `${product.package_weight} ${product.weight_unit || 'kg'}` : '',
    dimensions: dimensions.length ? `${dimensions.length} x ${dimensions.width} x ${dimensions.height} ${dimensions.unit || 'cm'}` : product.dimensions || '',
    dispatchTime: product.dispatch_time || '',
    hsnGst: product.hsn_gst || '',
    countryOfOrigin: product.country_of_origin || '',
    useStoreDelivery: product.use_store_delivery_settings ?? true,
    returnPolicy: product.return_policy || '',
    useStoreReturnPolicy: product.use_store_return_policy ?? true,
    warranty: product.warranty || 'None',
    highlights: product.key_highlights || product.highlights || [],
    variants: (product.variants || []).map((variant, index) => ({
      id: variant.id || variant._id || `${id || 'variant'}-${index}`,
      color: variant.color || '#8B5E3C',
      size: variant.size || '',
      stock: String(variant.stock_quantity ?? variant.stock ?? ''),
      price: String(variant.price ?? ''),
    })),
    rating: Number(product.rating ?? 0),
    reviews: Number(product.reviews ?? product.reviews_count ?? 0),
    views: Number(product.views ?? product.views_count ?? 0),
    vendorRating: Number(product.vendorRating ?? seller.rating ?? 0),
    vendorLocation: seller.location?.name || seller.location || '',
    seller,
  };
};

export const productFormToApiPayload = ({ form, highlights, variants, images, status }) => ({
  images,
  name: form.name.trim(),
  category: form.category,
  brand: form.brand.trim(),
  short_description: form.shortDescription.trim(),
  key_highlights: highlights.map((item) => item.trim()).filter(Boolean),
  mrp: Number(form.mrp) || 0,
  selling_price: Number(form.sellingPrice) || 0,
  stock_quantity: Number(form.stockQuantity) || 0,
  seller_sku: form.sku.trim(),
  track_inventory: Boolean(form.trackInventory),
  status: apiStatus(status),
  variants: variants
    .filter((variant) => variant.color || variant.size || variant.stock || variant.price)
    .map((variant) => ({
      color: variant.color,
      size: variant.size || 'One Size',
      stock_quantity: Number(variant.stock) || 0,
      price: Number(variant.price) || Number(form.sellingPrice) || 0,
    })),
  package_weight: Number(form.packageWeight) || 0,
  weight_unit: form.weightUnit || 'kg',
  dimensions: {
    length: Number(form.dimLength) || 0,
    width: Number(form.dimWidth) || 0,
    height: Number(form.dimHeight) || 0,
    unit: 'cm',
  },
  dispatch_time: form.dispatchTime.trim(),
  hsn_gst: form.hsnGst.trim(),
  country_of_origin: form.countryOfOrigin,
  return_policy: form.returnPolicy,
  use_store_delivery_settings: Boolean(form.useStoreDelivery),
  use_store_return_policy: Boolean(form.useStoreReturnPolicy),
  warranty: form.warranty,
});

// Uploads all files in a single multipart request — one round trip instead of
// one request per image. Returns results in the same order the files were given.
export const uploadInfluencerProductImages = async (files) => {
  if (!files.length) return [];
  const formData = new FormData();
  files.forEach((file) => formData.append('files', file));
  const { data } = await api.post('/upload/influencer-product', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return (data.images || []).map((img) => ({
    fileName: normalizeUploadPath(img.fileName || img.fileUrl),
  }));
};

export const prepareProductImages = async (images) => {
  const newFiles = images.filter((img) => img.file).map((img) => img.file);
  const uploaded = await uploadInfluencerProductImages(newFiles);
  let uploadIndex = 0;
  return images.map((img) => (
    img.file ? uploaded[uploadIndex++] : { fileName: normalizeUploadPath(img.fileName || img.url) }
  ));
};

const influencerProductService = {
  list: async () => {
    const { data } = await api.get('/influencer-products');
    return firstArray(data).map(normalizeInfluencerProduct);
  },
  listMine: async () => {
    const { data } = await api.get('/influencer-products/my');
    return firstArray(data).map(normalizeInfluencerProduct);
  },
  get: async (id) => {
    const { data } = await api.get(`/influencer-products/${id}`);
    return normalizeInfluencerProduct(data.product || data.data || data);
  },
  create: async (payload) => {
    const { data } = await api.post('/influencer-products', payload);
    return normalizeInfluencerProduct(data.product || data.data || data);
  },
  update: async (id, payload) => {
    const { data } = await api.patch(`/influencer-products/${id}`, payload);
    return normalizeInfluencerProduct(data.product || data.data || data);
  },
  addStock: async (id, quantity) => {
    const { data } = await api.patch(`/influencer-products/${id}/stock`, { quantity });
    return normalizeInfluencerProduct(data.product || data.data || data);
  },
  remove: async (id) => api.delete(`/influencer-products/${id}`),
};

export default influencerProductService;
