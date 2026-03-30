import React, { useEffect, useMemo, useState } from 'react';
import { CheckCircle2, ChevronRight, Loader2, X } from 'lucide-react';
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
};

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
  const [submittingReason, setSubmittingReason] = useState('');
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(false);

  const label = useMemo(() => CONTENT_LABELS[contentType] || 'content', [contentType]);

  useEffect(() => {
    if (!isOpen) return;
    setStep('menu');
    setError('');
    setSubmittingReason('');
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
    } catch (err) {
      setReasons(FALLBACK_REASONS);
      setError('');
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

  const handleSubmitReason = async (reason) => {
    if (!contentType || !contentId || submittingReason) return;
    setSubmittingReason(reason);
    setError('');
    try {
      await api.post('/content-reports', {
        content_type: contentType,
        content_id: contentId,
        reason,
      });
      setStep('success');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to submit report');
    } finally {
      setSubmittingReason('');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[140] flex items-center justify-center bg-black/75 px-4 py-6 backdrop-blur-sm">
      <div className="absolute inset-0" onClick={onClose} />

      <div className="relative w-full max-w-[520px] overflow-hidden rounded-[24px] border border-white/10 bg-[#26272b] text-white shadow-[0_32px_96px_rgba(0,0,0,0.6)]">
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
                onClick={() => {
                  setStep('menu');
                  setError('');
                }}
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
                    onClick={() => handleSubmitReason(reason)}
                    disabled={!!submittingReason}
                    className="flex w-full items-center justify-between border-b border-white/10 px-5 py-4 text-left text-[15px] text-white transition-colors hover:bg-white/[0.03] disabled:cursor-not-allowed disabled:opacity-70"
                  >
                    <span className="pr-4 leading-6">{reason}</span>
                    {submittingReason === reason ? (
                      <Loader2 size={16} className="animate-spin text-white/55" />
                    ) : (
                      <ChevronRight size={16} className="text-white/45" />
                    )}
                  </button>
                ))}
              </div>
            )}

            {error ? <p className="px-5 py-3 text-xs text-red-300">{error}</p> : null}
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
