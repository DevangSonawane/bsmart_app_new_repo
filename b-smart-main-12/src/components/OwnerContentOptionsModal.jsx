import React, { useMemo, useState } from 'react';
import api from '../lib/api';

const getEndpoint = (contentType, itemId) => {
  if (contentType === 'ad') return `/ads/${itemId}/metadata`;
  if (contentType === 'reel') return `/posts/reels/${itemId}/metadata`;
  return `/posts/${itemId}/metadata`;
};

export default function OwnerContentOptionsModal({
  isOpen,
  onClose,
  item,
  contentType = 'post',
  onEdit,
  onDelete,
  onUpdated,
  contentUrl = '',
}) {
  const [busyKey, setBusyKey] = useState('');

  const itemId = item?._id || item?.post_id || item?.id;
  const hideLikes = !!(item?.engagement_controls?.hide_likes_count ?? item?.hide_likes_count);
  const disableComments = !!(item?.engagement_controls?.disable_comments ?? item?.turn_off_commenting);

  const labels = useMemo(() => ({
    delete: contentType === 'ad' ? 'Delete' : 'Delete',
    edit: 'Edit',
    likes: hideLikes ? 'Unhide like count to others' : 'Hide like count from others',
    comments: disableComments ? 'Turn on commenting' : 'Turn off commenting',
  }), [contentType, hideLikes, disableComments]);

  if (!isOpen || !itemId) return null;

  const applyUpdate = async (payload, key) => {
    setBusyKey(key);
    try {
      const { data } = await api.patch(getEndpoint(contentType, itemId), payload);
      onUpdated?.(data);
      onClose?.();
    } catch (err) {
      alert(err?.response?.data?.message || 'Failed to update.');
    } finally {
      setBusyKey('');
    }
  };

  const handleToggleLikes = () => {
    if (contentType === 'ad') {
      applyUpdate({
        engagement_controls: {
          hide_likes_count: !hideLikes,
          disable_comments: disableComments,
        },
      }, 'likes');
      return;
    }

    applyUpdate({
      hide_likes_count: !hideLikes,
      turn_off_commenting: disableComments,
    }, 'likes');
  };

  const handleToggleComments = () => {
    if (contentType === 'ad') {
      applyUpdate({
        engagement_controls: {
          hide_likes_count: hideLikes,
          disable_comments: !disableComments,
        },
      }, 'comments');
      return;
    }

    applyUpdate({
      hide_likes_count: hideLikes,
      turn_off_commenting: !disableComments,
    }, 'comments');
  };

  const handleShare = async () => {
    if (!contentUrl) return;
    try {
      if (navigator.share) {
        await navigator.share({ url: contentUrl });
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(contentUrl);
      }
      onClose?.();
    } catch {
      /* noop */
    }
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

  const handleGoToPost = () => {
    if (!contentUrl) return;
    window.location.href = contentUrl;
  };

  const actionClass = 'w-full border-b border-white/10 px-6 py-[15px] text-center text-[15px] font-medium text-white hover:bg-white/[0.04] transition-colors';

  return (
    <div className="fixed inset-0 z-[85] flex items-center justify-center bg-black/55 backdrop-blur-sm p-4">
      <div className="w-full max-w-[620px] overflow-hidden rounded-[28px] border border-white/10 bg-[#26272c] shadow-2xl">
        <button className={`${actionClass} text-[#ff4d67] font-semibold`} onClick={onDelete}>
          {labels.delete}
        </button>
        <button className={actionClass} onClick={onEdit}>
          {labels.edit}
        </button>
        <button className={actionClass} onClick={handleToggleLikes} disabled={busyKey === 'likes'}>
          {busyKey === 'likes' ? 'Saving...' : labels.likes}
        </button>
        <button className={actionClass} onClick={handleToggleComments} disabled={busyKey === 'comments'}>
          {busyKey === 'comments' ? 'Saving...' : labels.comments}
        </button>
        <button className={actionClass} onClick={handleGoToPost}>
          Go to post
        </button>
        <button className={actionClass} onClick={handleShare}>
          Share to...
        </button>
        <button className={actionClass} onClick={handleCopyLink}>
          Copy link
        </button>
        <button className={actionClass} onClick={onClose}>
          Embed
        </button>
        <button className={actionClass} onClick={onClose}>
          About this account
        </button>
        <button className="w-full px-6 py-4 text-center text-[15px] font-medium text-white hover:bg-white/[0.04] transition-colors" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  );
}
