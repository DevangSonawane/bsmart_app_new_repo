import { useState, useRef, useEffect, useCallback } from 'react';

// Shared click / drag-drop / paste-from-clipboard image uploader, used by the
// Add/Edit Product and Add/Edit Service forms.
//
// Pass `options.uploadFn` (e.g. uploadInfluencerProductImages) to upload each
// selected file to the backend immediately. Uploaded entries carry the real
// `fileUrl` — drop those straight into the listing payload's `images` field.
// While any entry is still uploading, `isUploading` is true and the form
// should block submit. Only real image files are accepted (the backend
// rejects anything else).
//
// Without `uploadFn` it falls back to local blob previews (legacy behavior).
const makeId = () => `${Date.now()}-${Math.random().toString(36).slice(2)}`;

const normalizeInitial = (initialImages) => (initialImages || []).map((item) => {
  if (typeof item === 'string') {
    return { id: makeId(), url: item, fileUrl: item.startsWith('blob:') ? null : item, fileName: null, existing: true };
  }
  const url = item?.fileUrl || item?.url || '';
  return {
    id: item?.id || makeId(),
    url,
    fileUrl: url && !url.startsWith('blob:') ? url : (item?.fileUrl || null),
    fileName: item?.fileName || null,
    existing: true,
  };
});

export default function useMediaUploader(initialImages = [], maxImages = 10, options = {}) {
  const { uploadFn } = options;
  const [images, setImages] = useState(() => normalizeInitial(initialImages));
  const [isDragging, setIsDragging] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const fileInputRef = useRef(null);
  const mountedRef = useRef(true);
  const countRef = useRef(images.length);
  useEffect(() => () => { mountedRef.current = false; }, []);

  const setAll = (updater) => setImages((prev) => {
    const next = typeof updater === 'function' ? updater(prev) : updater;
    countRef.current = next.length;
    return next;
  });

  const isUploading = images.some((img) => img.uploading);
  // Only real (uploaded or pre-existing remote) URLs — never blob previews.
  const uploadedUrls = images
    .filter((img) => !img.uploading && !img.error)
    .map((img) => img.fileUrl || img.url)
    .filter((url) => url && !url.startsWith('blob:'));

  const addFiles = useCallback((fileList) => {
    const picked = Array.from(fileList || []);
    if (!picked.length) return;
    const valid = picked.filter((f) => f.type && f.type.startsWith('image/'));
    if (!valid.length) {
      setUploadError('Only image files (JPG, PNG, WEBP…) can be uploaded');
      return;
    }
    if (valid.length < picked.length) {
      setUploadError('Some files were skipped — only real image files are accepted');
    }
    const room = maxImages - countRef.current;
    if (room <= 0) {
      setUploadError(`Maximum ${maxImages} images allowed`);
      return;
    }
    const accepted = valid.slice(0, room);
    setUploadError('');

    // Local-only mode — instant blob previews, no backend involved.
    if (typeof uploadFn !== 'function') {
      setAll((prev) => [
        ...prev,
        ...accepted.map((file) => ({ id: makeId(), url: URL.createObjectURL(file) })),
      ]);
      return;
    }

    // Remote mode — temp previews first, swap in real fileUrls on success.
    const temps = accepted.map((file) => ({ id: makeId(), url: URL.createObjectURL(file), uploading: true }));
    setAll((prev) => [...prev, ...temps]);
    uploadFn(accepted).then((uploaded) => {
      if (!mountedRef.current) return;
      setAll((prev) => prev.map((img) => {
        const idx = temps.findIndex((t) => t.id === img.id);
        if (idx === -1) return img;
        const done = uploaded[idx] || uploaded[0];
        if (!done) return { ...img, uploading: false, error: true };
        URL.revokeObjectURL(img.url);
        return { ...img, uploading: false, url: done.fileUrl, fileUrl: done.fileUrl, fileName: done.fileName };
      }));
    }).catch((err) => {
      if (!mountedRef.current) return;
      const tempIds = new Set(temps.map((t) => t.id));
      setAll((prev) => prev.filter((img) => !tempIds.has(img.id)));
      setUploadError(err?.message || 'Image upload failed');
    });
  }, [maxImages, uploadFn]);

  const handleFileInput = (e) => { addFiles(e.target.files); e.target.value = ''; };
  const handleDrop = (e) => { e.preventDefault(); setIsDragging(false); addFiles(e.dataTransfer.files); };
  const handleDragOver = (e) => { e.preventDefault(); setIsDragging(true); };
  const handleDragLeave = () => setIsDragging(false);
  const removeImage = (id) => setAll((prev) => {
    const target = prev.find((img) => img.id === id);
    if (target?.url?.startsWith('blob:')) URL.revokeObjectURL(target.url);
    return prev.filter((img) => img.id !== id);
  });
  const clearUploadError = () => setUploadError('');

  // Paste an image straight from the clipboard (Ctrl+V) anywhere on the page.
  useEffect(() => {
    const handlePaste = (e) => {
      const items = e.clipboardData?.items;
      if (!items) return;
      const files = [];
      for (const item of items) {
        if (item.type.startsWith('image/')) {
          const file = item.getAsFile();
          if (file) files.push(file);
        }
      }
      if (files.length) addFiles(files);
    };
    window.addEventListener('paste', handlePaste);
    return () => window.removeEventListener('paste', handlePaste);
  }, [addFiles]);

  // Release blob URLs (not the pre-existing remote ones) when the page unmounts.
  useEffect(() => () => {
    images.forEach((img) => { if (!img.existing && img.url?.startsWith('blob:')) URL.revokeObjectURL(img.url); });
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return {
    images, isDragging, fileInputRef,
    handleFileInput, handleDrop, handleDragOver, handleDragLeave, removeImage,
    isUploading, uploadError, clearUploadError, uploadedUrls,
  };
}
