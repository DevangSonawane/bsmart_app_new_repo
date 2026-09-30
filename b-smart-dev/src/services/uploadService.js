import api from '../lib/api';

// ── Influencer listing image uploads ─────────────────────────────────────────
//   POST /upload/influencer-product  (multipart/form-data, field: `files`)
//   POST /upload/influencer-service  (multipart/form-data, field: `files`)
// Both return { success: true, images: [{ fileName, fileUrl }], count }.
// Drop the returned `fileUrl` strings straight into the `images` field of
// POST /api/influencer-products (or -services). The backend rejects anything
// that isn't a real image, so only upload validated image files here.

const normalizeImages = (payload) => {
  const raw = payload?.images ?? payload?.data?.images ?? [];
  if (!Array.isArray(raw)) return [];
  return raw
    .map((img) => {
      if (typeof img === 'string') return { fileName: img.split('/').pop() || img, fileUrl: img };
      if (img && typeof img === 'object') {
        const fileUrl = img.fileUrl || img.file_url || img.url;
        if (!fileUrl) return null;
        return { fileName: img.fileName || img.file_name || String(fileUrl).split('/').pop(), fileUrl };
      }
      return null;
    })
    .filter(Boolean);
};

const uploadMany = async (endpoint, files) => {
  const list = Array.from(files || []).filter(Boolean);
  if (!list.length) throw new Error('No files selected');
  const bad = list.find((f) => !f.type || !f.type.startsWith('image/'));
  if (bad) throw new Error(`"${bad.name || 'File'}" is not an image — only JPG, PNG, WEBP etc. are accepted`);
  const form = new FormData();
  list.forEach((file) => form.append('files', file));
  try {
    const res = await api.post(endpoint, form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    const images = normalizeImages(res?.data);
    if (!images.length) throw new Error('Upload succeeded but returned no images');
    return images;
  } catch (error) {
    const message =
      error?.response?.data?.message ||
      error?.response?.data?.error ||
      (error?.response?.status === 400 && 'Invalid files — only real image files are accepted') ||
      error?.message ||
      'Image upload failed';
    throw new Error(message);
  }
};

export const uploadInfluencerProductImages = (files) => uploadMany('/upload/influencer-product', files);
export const uploadInfluencerServiceImages = (files) => uploadMany('/upload/influencer-service', files);

export default {
  uploadInfluencerProductImages,
  uploadInfluencerServiceImages,
};
