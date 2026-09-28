import React, { useEffect, useMemo, useState } from 'react';
import { Check, CheckCircle2, ChevronRight, Film, Image as ImageIcon, Loader2, Plus, X } from 'lucide-react';
import api from '../lib/api';

const FALLBACK_REASONS = [
  "I just don't like it",
  'Bullying or unwanted contact',
  'Suicide, self-injury or eating disorders',
  'Violence, hate or exploitation',
  'Selling or promoting restricted items',
  'Nudity or sexual activity',
  'Scam, fraud or spam',
  'False information',
];

const CONTENT_LABELS = {
  post: 'post',
  reel: 'reel',
  story: 'story',
  ad: 'ad',
  comment: 'comment',
  tweet: 'tweet',
  promote_reel: 'reel',
};

const INPUT_CLS = 'w-full px-3.5 py-2.5 rounded-xl border border-white/10 bg-white/5 text-sm text-white outline-none focus:ring-2 focus:ring-[#ff4d67]/30 focus:border-[#ff4d67]/60 placeholder-white/40 transition-all';

const ContentReportModal = ({
  isOpen,
  onClose,
  contentType,
  contentId,
  contentUrl = '',
}) => {
  const [step, setStep] = useState('menu');
  const [reasons, setReasons] = useState([]);
  const [loadingReasons, setLoadingReasons] = useState(false);
  const [selectedReason, setSelectedReason] = useState('');
  const [details, setDetails] = useState('');
  const [attachments, setAttachments] = useState([]); // { id, name, type, url, uploading, error }
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(false);

  const label = useMemo(() => CONTENT_LABELS[contentType] || 'content', [contentType]);

  useEffect(() => {
    if (!isOpen) return;
    setStep('menu');
    setError('');
    setSelectedReason('');
    setDetails('');
    setAttachments([]);
    setSubmitting(false);
    setCopied(false);
  }, [isOpen, contentId, contentType]);

  useEffect(() => {
    if (!copied) return undefined;
    const timer = setTimeout(() => setCopied(false), 1800);
    return () => clearTimeout(timer);
  }, [copied]);

  const loadReasons = async () => {
    if (loadingReasons || reasons.length > 0) return;
    setLoadingReasons(true);
    setError('');
    try {
      const { data } = await api.get('/content-reports/reasons');
      const fetchedReasons = Array.isArray(data?.reasons) && data.reasons.length > 0
        ? data.reasons
        : FALLBACK_REASONS;
      setReasons(fetchedReasons);
    } catch {
      setReasons(FALLBACK_REASONS);
    } finally {
      setLoadingReasons(false);
    }
  };

  const openReasons = async () => {
    setStep('reasons');
    await loadReasons();
  };

  const handleCopyLink = async () => {
    if (!contentUrl) return;
    try {
      await navigator.clipboard.writeText(contentUrl);
      setCopied(true);
    } catch {
      setError('Could not copy link');
    }
  };

  const pickReason = (reason) => {
    setSelectedReason(reason);
    setError('');
    setStep('details');
  };

  const handleFiles = async (files) => {
    for (const file of Array.from(files || [])) {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const isVideo = file.type.startsWith('video/');
      setAttachments((prev) => [...prev, { id, name: file.name, type: isVideo ? 'video' : 'image', uploading: true }]);
      try {
        const fd = new FormData();
        fd.append('file', file);
        const res = await api.post('/upload/post', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
        const url = res.data?.media?.url || res.data?.fileUrl || res.data?.url;
        const type = res.data?.media_type === 'video' ? 'video' : 'image';
        setAttachments((prev) => prev.map((a) => (a.id === id ? { ...a, uploading: false, url, type } : a)));
      } catch {
        setAttachments((prev) => prev.map((a) => (a.id === id ? { ...a, uploading: false, error: true } : a)));
      }
    }
  };

  const removeAttachment = (id) => setAttachments((prev) => prev.filter((a) => a.id !== id));

  const handleSubmitReport = async () => {
    if (!contentType || !contentId || !selectedReason || submitting) return;
    if (attachments.some((a) => a.uploading)) { setError('Please wait for attachments to finish uploading.'); return; }
    setSubmitting(true);
    setError('');
    try {
      await api.post('/content-reports', {
        content_type: contentType,
        content_id: contentId,
        reason: selectedReason,
        details: details.trim(),
        attachments: attachments.filter((a) => a.url).map((a) => ({ url: a.url, type: a.type })),
      });
      setStep('success');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to submit report');
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[140] flex items-start justify-center bg-black/75 px-4 py-20 backdrop-blur-sm overflow-y-auto">
      <div className="absolute inset-0" onClick={onClose} />

      <div className="relative w-full max-w-[520px] overflow-hidden rounded-[24px] border border-white/10 bg-[#26272b] text-white shadow-[0_32px_96px_rgba(0,0,0,0.6)] mt-4 md:mt-8">
        {step === 'menu' && (
          <div>
            <div className="border-b border-white/10 px-5 py-4 text-center text-[22px] font-semibold tracking-tight md:text-[24px]">
              Report
            </div>

            <button
              onClick={openReasons}
              className="flex w-full items-center justify-center border-b border-white/10 px-5 py-4 text-center text-[17px] font-semibold text-[#ff4d67] transition-colors hover:bg-white/[0.03]"
            >
              Report
            </button>

            {contentUrl ? (
              <button
                onClick={handleCopyLink}
                className="flex w-full items-center justify-center border-b border-white/10 px-5 py-4 text-center text-[16px] font-medium text-white transition-colors hover:bg-white/[0.03]"
              >
                {copied ? 'Link copied' : 'Copy link'}
              </button>
            ) : null}

            <button
              onClick={onClose}
              className="flex w-full items-center justify-center px-5 py-4 text-center text-[16px] font-medium text-white transition-colors hover:bg-white/[0.03]"
            >
              Cancel
            </button>

            {error ? <p className="px-5 pb-4 text-center text-xs text-red-300">{error}</p> : null}
          </div>
        )}

        {step === 'reasons' && (
          <div>
            <div className="flex items-center border-b border-white/10 px-4 py-3.5">
              <button
                onClick={() => { setStep('menu'); setError(''); }}
                className="rounded-full p-1 text-white/85 transition-colors hover:bg-white/5 hover:text-white"
              >
                <X size={24} />
              </button>
              <div className="flex-1 text-center text-[18px] font-semibold">Report</div>
              <div className="w-7" />
            </div>

            <div className="border-b border-white/10 px-5 py-5 text-[16px] font-semibold">
              Why are you reporting this {label}?
            </div>

            {loadingReasons ? (
              <div className="flex items-center justify-center gap-3 px-5 py-10 text-sm text-white/70">
                <Loader2 size={18} className="animate-spin" />
                <span>Loading reasons...</span>
              </div>
            ) : (
              <div>
                {reasons.map((reason) => (
                  <button
                    key={reason}
                    onClick={() => pickReason(reason)}
                    className="flex w-full items-center justify-between border-b border-white/10 px-5 py-4 text-left text-[15px] text-white transition-colors hover:bg-white/[0.03]"
                  >
                    <span className="pr-4 leading-6">{reason}</span>
                    <ChevronRight size={16} className="text-white/45" />
                  </button>
                ))}
              </div>
            )}

            {error ? <p className="px-5 py-3 text-xs text-red-300">{error}</p> : null}
          </div>
        )}

        {step === 'details' && (
          <div>
            <div className="flex items-center border-b border-white/10 px-4 py-3.5">
              <button
                onClick={() => { setStep('reasons'); setError(''); }}
                className="rounded-full p-1 text-white/85 transition-colors hover:bg-white/5 hover:text-white"
              >
                <X size={24} />
              </button>
              <div className="flex-1 text-center text-[18px] font-semibold">Report</div>
              <div className="w-7" />
            </div>

            <div className="px-5 py-5 space-y-4">
              <div>
                <p className="text-[11px] font-bold text-white/40 uppercase tracking-widest mb-1.5">Reason</p>
                <p className="text-[15px] font-semibold text-[#ff4d67]">{selectedReason}</p>
              </div>

              <div>
                <label className="text-xs font-semibold text-white/60 mb-1.5 block">Additional details (optional)</label>
                <textarea
                  value={details}
                  onChange={(e) => setDetails(e.target.value)}
                  rows={4}
                  maxLength={1000}
                  placeholder="Anything else we should know?"
                  className={`${INPUT_CLS} resize-none`}
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-white/60 mb-1.5 block">Attachments (optional)</label>
                <input
                  id="report-attachment-input"
                  type="file"
                  accept="image/*,video/*"
                  multiple
                  className="hidden"
                  onChange={(e) => { handleFiles(e.target.files); e.target.value = ''; }}
                />
                <button
                  type="button"
                  onClick={() => document.getElementById('report-attachment-input')?.click()}
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl border-2 border-dashed border-white/15 text-xs font-semibold text-white/60 hover:border-[#ff4d67]/40 hover:text-[#ff4d67] transition-colors"
                >
                  <Plus size={14} /> Add screenshot or screen recording
                </button>
                {attachments.length > 0 && (
                  <div className="mt-2 space-y-1.5">
                    {attachments.map((a) => (
                      <div key={a.id} className="flex items-center gap-2 px-3 py-2 rounded-lg bg-white/5 text-xs">
                        {a.type === 'video' ? <Film size={13} className="text-white/40 shrink-0" /> : <ImageIcon size={13} className="text-white/40 shrink-0" />}
                        <span className="flex-1 truncate text-white/80">{a.name}</span>
                        {a.uploading ? <Loader2 size={13} className="animate-spin text-white/40 shrink-0" />
                          : a.error ? <span className="text-red-300 shrink-0">Failed</span>
                          : <Check size={13} className="text-emerald-400 shrink-0" />}
                        <button type="button" onClick={() => removeAttachment(a.id)} className="text-white/30 hover:text-red-300 shrink-0"><X size={13} /></button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {error ? <p className="text-xs text-red-300">{error}</p> : null}

              <button
                onClick={handleSubmitReport}
                disabled={submitting}
                className="w-full rounded-xl bg-gradient-to-r from-[#4f5af7] to-[#5862ff] px-5 py-3 text-[15px] font-semibold text-white transition-opacity hover:opacity-95 disabled:opacity-60 flex items-center justify-center gap-2"
              >
                {submitting ? <><Loader2 size={15} className="animate-spin" /> Submitting…</> : 'Submit Report'}
              </button>
            </div>
          </div>
        )}

        {step === 'success' && (
          <div className="px-6 py-7 text-center md:px-8 md:py-8">
            <div className="mb-4 flex justify-center">
              <div className="rounded-full border-[3px] border-[#59d11f] p-2">
                <CheckCircle2 size={42} className="text-[#59d11f]" strokeWidth={2.4} />
              </div>
            </div>

            <h3 className="text-[17px] font-semibold md:text-[18px]">Reported</h3>
            <p className="mx-auto mt-2.5 max-w-[380px] text-[14px] leading-6 text-white/70">
              Your report has been submitted successfully.
            </p>

            <button
              onClick={onClose}
              className="mt-6 w-full rounded-xl bg-gradient-to-r from-[#4f5af7] to-[#5862ff] px-5 py-3 text-[16px] font-semibold text-white transition-opacity hover:opacity-95"
            >
              Close
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default ContentReportModal;
