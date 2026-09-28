import { useState, useRef, useEffect, useCallback } from 'react';

// Shared click / drag-drop / paste-from-clipboard image uploader, used by
// both the Add Product and Edit Product forms.
export default function useMediaUploader(initialImages = [], maxImages = 10) {
  const [images, setImages] = useState(
    initialImages.map((url) => ({ id: `${Date.now()}-${Math.random().toString(36).slice(2)}`, url, existing: true }))
  );
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef(null);

  const addFiles = useCallback((fileList) => {
    const files = Array.from(fileList).filter((f) => f.type.startsWith('image/') || f.type.startsWith('video/'));
    if (!files.length) return;
    setImages((prev) => {
      const room = maxImages - prev.length;
      if (room <= 0) return prev;
      const toAdd = files.slice(0, room).map((file) => ({
        id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
        url: URL.createObjectURL(file),
      }));
      return [...prev, ...toAdd];
    });
  }, [maxImages]);

  const handleFileInput = (e) => { addFiles(e.target.files); e.target.value = ''; };
  const handleDrop = (e) => { e.preventDefault(); setIsDragging(false); addFiles(e.dataTransfer.files); };
  const handleDragOver = (e) => { e.preventDefault(); setIsDragging(true); };
  const handleDragLeave = () => setIsDragging(false);
  const removeImage = (id) => setImages((prev) => prev.filter((img) => img.id !== id));

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
    images.forEach((img) => { if (!img.existing) URL.revokeObjectURL(img.url); });
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return {
    images, isDragging, fileInputRef,
    handleFileInput, handleDrop, handleDragOver, handleDragLeave, removeImage,
  };
}
