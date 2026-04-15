import React, { useEffect, useMemo, useState } from 'react';
import { MapPin, Smile, Tag, X } from 'lucide-react';
import api from '../lib/api';

const splitList = (value) =>
  String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

const normalizeHashTags = (value) =>
  splitList(value).map((item) => item.replace(/^#+/, ''));

const getInitialValues = (contentType, item) => ({
  caption: item?.caption || '',
  location: item?.location || '',
  hashtags:
    contentType === 'ad'
      ? (item?.hashtags || []).map((tag) => String(tag).replace(/^#+/, '')).join(', ')
      : (item?.tags || []).map((tag) => String(tag).replace(/^#+/, '')).join(', '),
  category: item?.category || '',
  targetLanguage: Array.isArray(item?.target_language) ? item.target_language.join(', ') : '',
  targetLocation: Array.isArray(item?.target_location) ? item.target_location.join(', ') : '',
  targetStates: Array.isArray(item?.target_states) ? item.target_states.join(', ') : '',
  totalBudgetCoins: item?.total_budget_coins != null ? String(item.total_budget_coins) : '',
  hideLikes: !!(item?.engagement_controls?.hide_likes_count ?? item?.hide_likes_count),
  disableComments: !!(item?.engagement_controls?.disable_comments ?? item?.turn_off_commenting),
});

const getEndpoint = (contentType, itemId) => {
  if (contentType === 'ad') return `/ads/${itemId}/metadata`;
  if (contentType === 'reel') return `/posts/reels/${itemId}/metadata`;
  return `/posts/${itemId}/metadata`;
};

const getPreviewUrl = (mediaItem) =>
  mediaItem?.fileUrl ||
  mediaItem?.url ||
  mediaItem?.thumbnail?.[0]?.fileUrl ||
  mediaItem?.thumbnails?.[0]?.fileUrl ||
  '';

function ToggleRow({ label, checked, onToggle }) {
  return (
    <button
      type="button"
      onClick={onToggle}
      className="flex w-full items-center justify-between gap-4 text-left text-[15px] text-white"
    >
      <span>{label}</span>
      <span className={`relative inline-flex h-6 w-11 shrink-0 rounded-full transition-colors ${checked ? 'bg-[#4f8cff]' : 'bg-white/15'}`}>
        <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${checked ? 'translate-x-5' : 'translate-x-0.5'}`} />
      </span>
    </button>
  );
}

function hideLikesLabel(hideLikes) {
  return hideLikes ? 'Unhide like count to others' : 'Hide like count from others';
}

export default function EditContentModal({ isOpen, onClose, item, contentType = 'post', onSaved }) {
  const [form, setForm] = useState(getInitialValues(contentType, item));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setForm(getInitialValues(contentType, item));
      setSaving(false);
      setError('');
    }
  }, [isOpen, contentType, item]);

  const itemId = item?._id || item?.post_id || item?.id;
  const profile = typeof item?.user_id === 'object' ? item.user_id : {};
  const username = profile?.username || profile?.full_name || 'user';
  const fullName = profile?.full_name || '';
  const avatarUrl = profile?.avatar_url || '';
  const previewMedia = item?.media?.[0];
  const previewUrl = getPreviewUrl(previewMedia);
  const isVideo = previewMedia?.type === 'video' || previewMedia?.media_type === 'video';
  const infoRows = useMemo(() => {
    if (contentType !== 'ad') return [];
    return [
      { key: 'category', placeholder: 'Category' },
      { key: 'targetLanguage', placeholder: 'Target languages' },
      { key: 'targetLocation', placeholder: 'Target locations' },
      { key: 'targetStates', placeholder: 'Target states' },
      { key: 'totalBudgetCoins', placeholder: 'Total budget (coins)' },
    ];
  }, [contentType]);

  if (!isOpen || !itemId) return null;

  const updateField = (key, value) => setForm((prev) => ({ ...prev, [key]: value }));

  const handleSubmit = async (e) => {
    if (e?.preventDefault) e.preventDefault();
    setSaving(true);
    setError('');

    const hashtagList = normalizeHashTags(form.hashtags);
    const payload =
      contentType === 'ad'
        ? {
            caption: form.caption,
            location: form.location,
            hashtags: hashtagList,
            tags: hashtagList,
            tagged_users: item?.tagged_users || [],
            engagement_controls: {
              hide_likes_count: !!form.hideLikes,
              disable_comments: !!form.disableComments,
            },
            content_type: item?.content_type || 'reel',
            category: form.category,
            target_language: splitList(form.targetLanguage),
            target_location: splitList(form.targetLocation),
            target_states: splitList(form.targetStates),
            total_budget_coins: Number(form.totalBudgetCoins || 0),
            target_preferences: Array.isArray(item?.target_preferences) ? item.target_preferences : [],
          }
        : {
            caption: form.caption,
            location: form.location,
            tags: hashtagList,
            people_tags: item?.people_tags || [],
            hide_likes_count: !!form.hideLikes,
            turn_off_commenting: !!form.disableComments,
          };

    try {
      const { data } = await api.patch(getEndpoint(contentType, itemId), payload);
      onSaved?.(data);
      onClose?.();
    } catch (err) {
      setError(err?.response?.data?.message || 'Failed to save changes.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/75 backdrop-blur-sm p-3 md:p-6">
      <div className="flex h-[92vh] w-full max-w-[1040px] flex-col overflow-hidden rounded-[28px] border border-white/10 bg-[#1f2126] text-white shadow-[0_30px_100px_rgba(0,0,0,0.7)]">
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <button onClick={onClose} className="text-[15px] font-medium text-white/90 transition-colors hover:text-white">
            Cancel
          </button>
          <h3 className="text-[15px] font-semibold">Edit info</h3>
          <button
            type="button"
            onClick={handleSubmit}
            disabled={saving}
            className="text-[15px] font-semibold text-[#4f8cff] transition-colors hover:text-[#76a3ff] disabled:opacity-60"
          >
            {saving ? 'Saving...' : 'Done'}
          </button>
        </div>

        <form onSubmit={handleSubmit} className="grid min-h-0 flex-1 md:grid-cols-[1.72fr_0.95fr]">
          <div className="flex min-h-[280px] items-center justify-center overflow-hidden bg-black">
            <div className="relative flex h-full w-full items-center justify-center overflow-hidden bg-black">
              {previewUrl ? (
                isVideo ? (
                  <video src={previewUrl} className="h-full max-h-full w-full object-contain" controls muted />
                ) : (
                  <img src={previewUrl} alt="Preview" className="h-full max-h-full w-full object-contain" />
                )
              ) : (
                <div className="flex h-full min-h-[280px] w-full items-center justify-center bg-[#111216] text-white/40">Preview</div>
              )}

              <div className="absolute left-4 top-4 rounded-full bg-black/70 px-3 py-1.5 text-[12px] text-white shadow-lg">
                Click photo to tag people
              </div>
            </div>
          </div>

          <div className="flex min-h-0 flex-col bg-[#26272c]">
            <div className="flex items-start gap-3 border-b border-white/10 px-5 py-5">
              <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-white/10 text-sm font-semibold">
                {avatarUrl ? (
                  <img src={avatarUrl} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span>{username[0]?.toUpperCase()}</span>
                )}
              </div>
              <div className="min-w-0">
                <p className="truncate text-[15px] font-semibold">{username}</p>
                <p className="truncate text-xs text-white/45">{fullName}</p>
              </div>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto">
              <div className="border-b border-white/10 px-5 py-4">
                <textarea
                  value={form.caption}
                  onChange={(e) => updateField('caption', e.target.value)}
                  rows={6}
                  className="w-full resize-none bg-transparent text-[15px] leading-7 text-white outline-none placeholder:text-white/35"
                  placeholder="Write a caption..."
                />
                <div className="mt-3 flex items-center justify-between text-white/45">
                  <Smile size={18} />
                  <span className="text-xs">{form.caption.length}/2,200</span>
                </div>
              </div>

              <div className="flex items-center gap-3 border-b border-white/10 px-5 py-4">
                <MapPin size={17} className="shrink-0 text-white/55" />
                <input
                  value={form.location}
                  onChange={(e) => updateField('location', e.target.value)}
                  className="w-full bg-transparent text-[15px] font-semibold text-white outline-none placeholder:font-normal placeholder:text-white/45"
                  placeholder="Add location"
                />
                {form.location ? (
                  <button type="button" onClick={() => updateField('location', '')} className="shrink-0 text-white/55 transition-colors hover:text-white">
                    <X size={18} />
                  </button>
                ) : null}
              </div>

              <div className="flex items-center gap-3 border-b border-white/10 px-5 py-4">
                <Tag size={17} className="shrink-0 text-white/55" />
                <input
                  value={form.hashtags}
                  onChange={(e) => updateField('hashtags', e.target.value)}
                  className="w-full bg-transparent text-[15px] text-white outline-none placeholder:text-white/45"
                  placeholder={contentType === 'ad' ? 'Add hashtags' : 'Add tags'}
                />
              </div>

              {infoRows.map((row) => (
                <div key={row.key} className="border-b border-white/10 px-5 py-4">
                  <input
                    value={form[row.key]}
                    onChange={(e) => updateField(row.key, e.target.value)}
                    className="w-full bg-transparent text-[15px] text-white outline-none placeholder:text-white/45"
                    placeholder={row.placeholder}
                  />
                </div>
              ))}

              <div className="border-b border-white/10 px-5 py-4">
                <ToggleRow
                  label={hideLikesLabel(form.hideLikes)}
                  checked={form.hideLikes}
                  onToggle={() => updateField('hideLikes', !form.hideLikes)}
                />
              </div>

              <div className="border-b border-white/10 px-5 py-4">
                <ToggleRow
                  label={contentType === 'ad' ? 'Disable comments' : form.disableComments ? 'Turn on commenting' : 'Turn off commenting'}
                  checked={form.disableComments}
                  onToggle={() => updateField('disableComments', !form.disableComments)}
                />
              </div>

              {error ? <p className="px-5 py-4 text-sm text-red-400">{error}</p> : null}
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}
