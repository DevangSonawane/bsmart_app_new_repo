import React, { useEffect } from 'react';

export default function OwnerContentOptionsModal({
  isOpen,
  onClose,
  item,
  contentType = 'post',
  onEdit,
  onDelete,
  contentUrl = '',
}) {
  const itemId = item?._id || item?.post_id || item?.id;

  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose?.(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [isOpen, onClose]);

  const handleShare = async () => {
    if (!contentUrl) return;
    try {
      if (navigator.share) {
        await navigator.share({ url: contentUrl });
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(contentUrl);
      }
      onClose?.();
    } catch { /* noop */ }
  };

  const handleCopyLink = async () => {
    if (!contentUrl) return;
    try {
      await navigator.clipboard.writeText(contentUrl);
      onClose?.();
    } catch {
      alert('Failed to copy link.');
    }
  };

  if (!isOpen || !itemId) return null;

  const actionClass = 'w-full border-b border-white/10 px-6 py-[15px] text-center text-[15px] font-medium text-white hover:bg-white/[0.04] transition-colors';

  return (
    <div className="fixed inset-0 z-[85] flex items-start justify-center bg-black/55 backdrop-blur-sm p-4 overflow-y-auto pt-16 md:pt-24">
      <div className="absolute inset-0" onClick={onClose} />
      <div className="relative w-full max-w-[620px] overflow-hidden rounded-[28px] border border-white/10 bg-[#26272c] shadow-2xl mt-4">
        <button className={`${actionClass} text-[#ff4d67] font-semibold`} onClick={onDelete}>
          Delete
        </button>
        <button className={actionClass} onClick={onEdit}>
          Edit
        </button>
        <button className={actionClass} onClick={handleShare}>
          Share to...
        </button>
        <button className={actionClass} onClick={handleCopyLink}>
          Copy link
        </button>
        <button
          className="w-full px-6 py-4 text-center text-[15px] font-medium text-white hover:bg-white/[0.04] transition-colors"
          onClick={onClose}
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
