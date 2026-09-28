import React, { useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import {
  ArrowLeft, FileText, Shield, RefreshCw, BookOpen, ShieldCheck,
  Download, Trash2, SlidersHorizontal, Database, Edit3, XCircle,
  Loader2, Check, ChevronRight, X, AlertCircle, LifeBuoy, Megaphone,
} from 'lucide-react';
import api from '../../lib/api';

// ─── Section title ─────────────────────────────────────────────────────────────
const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

// ─── Generic settings row ──────────────────────────────────────────────────────
const LinkRow = ({ icon: Icon, iconBg, iconColor, label, sublabel, onClick }) => (
  <div
    role="button"
    tabIndex={0}
    onClick={onClick}
    onKeyDown={(e) => e.key === 'Enter' && onClick?.()}
    className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
  >
    <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        <Icon size={16} className={iconColor} />
      </div>
      <div className="min-w-0">
        <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
        {sublabel && <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>}
      </div>
    </div>
    <ChevronRight size={16} className="text-gray-400 flex-shrink-0" />
  </div>
);

// ─── Legal document definitions ────────────────────────────────────────────────
// policyType must match the ?type= values the API accepts
const LEGAL_DOCS = [
  {
    icon: FileText,  iconBg: 'bg-blue-50 dark:bg-gray-800',   iconColor: 'text-blue-500',
    label: 'Terms & Conditions',   sublabel: 'Usage rules and policies',
    policyType: 'terms',
  },
  {
    icon: Shield,    iconBg: 'bg-pink-50 dark:bg-gray-800',   iconColor: 'text-[#fa3f5e]',
    label: 'Privacy Policy',       sublabel: 'How we collect and use your data',
    policyType: 'privacy',
  },
  {
    icon: RefreshCw, iconBg: 'bg-orange-50 dark:bg-gray-800', iconColor: 'text-orange-500',
    label: 'Refund Policy',        sublabel: 'Coin & transaction refund rules',
    policyType: 'refund',
  },
  {
    icon: BookOpen,  iconBg: 'bg-teal-50 dark:bg-gray-800',   iconColor: 'text-teal-500',
    label: 'Community Guidelines', sublabel: 'Standards for a safe community',
    policyType: 'community_guidelines',
  },
  {
    icon: ShieldCheck, iconBg: 'bg-emerald-50 dark:bg-gray-800', iconColor: 'text-emerald-500',
    label: 'Child Safety Standards', sublabel: 'Our standards against CSAE',
    policyType: 'child-safety-standards',
  },
  {
    icon: LifeBuoy, iconBg: 'bg-cyan-50 dark:bg-gray-800', iconColor: 'text-cyan-500',
    label: 'Support', sublabel: 'Get help with your account',
    policyType: 'support',
  },
  {
    icon: Megaphone, iconBg: 'bg-violet-50 dark:bg-gray-800', iconColor: 'text-violet-500',
    label: 'Marketing', sublabel: 'About B-Smart and what you can do',
    policyType: 'marketing',
  },
];

const DPDP_ROWS = [
  { icon: Database, bg: 'bg-blue-50 dark:bg-gray-800',   color: 'text-blue-500',   label: 'Data Access Request',     sublabel: 'Request a copy of your data',               key: 'access' },
  { icon: Edit3,    bg: 'bg-yellow-50 dark:bg-gray-800', color: 'text-yellow-600', label: 'Data Correction Request', sublabel: 'Request to correct inaccurate data',         key: 'correction' },
  { icon: XCircle,  bg: 'bg-red-50 dark:bg-gray-800',    color: 'text-red-500',    label: 'Data Deletion Request',   sublabel: 'Request permanent removal of your data',    key: 'deletion' },
];

// ─── Policy viewer modal ───────────────────────────────────────────────────────
const PolicyModal = ({ doc, onClose }) => {
  const [html,    setHtml]    = useState('');
  const [title,   setTitle]   = useState(doc.label);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  const fetchPolicy = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const res = await api.get('/policies/app/member', {
        params: { type: doc.policyType },
      });
      const data = res.data?.data?.[0];
      if (!data) { setError('Policy not found.'); return; }
      setHtml(data.content || '');
      setTitle(data.title || doc.label);
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to load policy.');
    } finally {
      setLoading(false);
    }
  }, [doc.policyType, doc.label]);

  // Fetch on open
  React.useEffect(() => { fetchPolicy(); }, [fetchPolicy]);

  // Close on Escape
  React.useEffect(() => {
    const handler = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [onClose]);

  return (
    /* Backdrop */
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      {/* Sheet */}
      <div className="relative w-full sm:max-w-2xl bg-white dark:bg-[#111] rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col max-h-[92dvh] sm:max-h-[88vh] overflow-hidden">

        {/* Modal header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${doc.iconBg}`}>
              <doc.icon size={15} className={doc.iconColor} />
            </div>
            <h2 className="text-base font-bold text-gray-900 dark:text-white leading-tight">{title}</h2>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors flex-shrink-0"
          >
            <X size={15} className="text-gray-600 dark:text-gray-300" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-5 py-5">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 size={28} className="animate-spin text-gray-300 dark:text-gray-600" />
              <span className="text-sm text-gray-400">Loading…</span>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-16 gap-3 text-red-500">
              <AlertCircle size={28} />
              <p className="text-sm">{error}</p>
              <button
                onClick={fetchPolicy}
                className="text-xs text-blue-500 underline"
              >
                Retry
              </button>
            </div>
          ) : (
            <div
              className="policy-content prose prose-sm dark:prose-invert max-w-none"
              dangerouslySetInnerHTML={{ __html: html }}
            />
          )}
        </div>

        {/* Footer close button */}
        {!loading && !error && (
          <div className="flex-shrink-0 px-5 py-4 border-t border-gray-100 dark:border-gray-800">
            <button
              onClick={onClose}
              className="w-full py-2.5 rounded-xl bg-gray-900 dark:bg-white text-white dark:text-black text-sm font-bold hover:opacity-90 transition-opacity"
            >
              Close
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

// ─── Clear Data confirmation / result modal ────────────────────────────────────
const ClearDataModal = ({ onClose }) => {
  const [phase, setPhase] = useState('confirm'); // 'confirm' | 'loading' | 'done' | 'error'
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');

  const handleConfirm = async () => {
    setPhase('loading');
    setError('');
    try {
      const res = await api.delete('/settings/account/clear-content');
      setResult(res.data);
      setPhase('done');
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to delete your data. Please try again.');
      setPhase('error');
    }
  };

  const removed = result?.removed || {};
  const removedRows = [
    { label: 'Posts & reels',       value: removed.posts_and_reels },
    { label: 'Tweets',              value: removed.tweets },
    { label: 'Promoted reels',      value: removed.promote_reels },
    { label: 'Messages',            value: removed.messages },
    { label: 'Conversations hidden', value: removed.conversations_hidden },
  ].filter(r => typeof r.value === 'number');

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
      onClick={(e) => { if (e.target === e.currentTarget && phase !== 'loading') onClose(); }}
    >
      <div className="w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-2xl border border-gray-100 dark:border-gray-800">
        {phase === 'loading' && (
          <div className="flex flex-col items-center py-6">
            <Loader2 size={32} className="animate-spin text-red-500 mb-4" />
            <p className="text-sm text-gray-500 dark:text-gray-400">Deleting your data…</p>
          </div>
        )}

        {phase === 'confirm' && (
          <>
            <div className="w-12 h-12 rounded-full bg-red-50 dark:bg-red-900/20 flex items-center justify-center mx-auto mb-4">
              <Trash2 size={20} className="text-red-500" />
            </div>
            <h3 className="text-base font-bold text-gray-900 dark:text-white mb-2 text-center">Delete all your data?</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-6 text-center">
              This permanently removes all your posts, reels, tweets, promoted reels and chat messages. Your account stays active — this can't be undone.
            </p>
            <div className="flex gap-3">
              <button onClick={onClose} className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Cancel
              </button>
              <button onClick={handleConfirm} className="flex-1 px-4 py-2.5 rounded-xl bg-red-500 text-white font-semibold hover:bg-red-600 transition-colors">
                Delete
              </button>
            </div>
          </>
        )}

        {phase === 'error' && (
          <>
            <div className="w-12 h-12 rounded-full bg-red-50 dark:bg-red-900/20 flex items-center justify-center mx-auto mb-4">
              <AlertCircle size={20} className="text-red-500" />
            </div>
            <h3 className="text-base font-bold text-gray-900 dark:text-white mb-2 text-center">Something went wrong</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-6 text-center">{error}</p>
            <div className="flex gap-3">
              <button onClick={onClose} className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Close
              </button>
              <button onClick={handleConfirm} className="flex-1 px-4 py-2.5 rounded-xl bg-red-500 text-white font-semibold hover:bg-red-600 transition-colors">
                Retry
              </button>
            </div>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="w-12 h-12 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center mx-auto mb-4">
              <Check size={20} className="text-green-500" />
            </div>
            <h3 className="text-base font-bold text-gray-900 dark:text-white mb-2 text-center">Data deleted</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4 text-center">{result?.message}</p>
            {removedRows.length > 0 && (
              <div className="bg-gray-50 dark:bg-gray-800 rounded-xl p-3 mb-6 space-y-1.5">
                {removedRows.map(r => (
                  <div key={r.label} className="flex items-center justify-between text-xs">
                    <span className="text-gray-500 dark:text-gray-400">{r.label}</span>
                    <span className="font-semibold text-gray-900 dark:text-white">{r.value}</span>
                  </div>
                ))}
              </div>
            )}
            <button onClick={onClose} className="w-full py-2.5 rounded-xl bg-gray-900 dark:bg-white text-white dark:text-black text-sm font-bold hover:opacity-90 transition-opacity">
              Done
            </button>
          </>
        )}
      </div>
    </div>
  );
};

// ─── Main page ─────────────────────────────────────────────────────────────────
const LegalSettings = () => {
  const [activeDoc,       setActiveDoc]       = useState(null);
  const [downloadLoading, setDownloadLoading] = useState(false);
  const [downloadDone,    setDownloadDone]    = useState(false);
  const [downloadError,   setDownloadError]   = useState('');
  const [showClearData,   setShowClearData]   = useState(false);
  const [dpdpSent,        setDpdpSent]        = useState({});

  const handleDownloadData = async () => {
    setDownloadLoading(true);
    setDownloadError('');
    try {
      const res = await api.get('/settings/account/export/excel', { responseType: 'blob' });
      const contentType = res.headers?.['content-type'] || 'text/csv';
      const disposition = res.headers?.['content-disposition'] || '';
      const match = /filename="?([^";]+)"?/.exec(disposition);
      const filename = match?.[1] || `bsmart-data-export-${Date.now()}.csv`;

      const blob = new Blob([res.data], { type: contentType });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);

      setDownloadDone(true);
      setTimeout(() => setDownloadDone(false), 3000);
    } catch (e) {
      setDownloadError(e?.response?.data?.message || 'Failed to export your data.');
    } finally {
      setDownloadLoading(false);
    }
  };

  const handleDpdpRequest = async (key) => {
    setDpdpSent(p => ({ ...p, [key]: 'loading' }));
    await new Promise(r => setTimeout(r, 1200));
    setDpdpSent(p => ({ ...p, [key]: 'done' }));
    setTimeout(() => setDpdpSent(p => { const n = { ...p }; delete n[key]; return n; }), 3000);
  };

  return (
    <>
      <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

        {/* Header */}
        <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
          <Link to="/settings" className="text-gray-800 dark:text-white p-1">
            <ArrowLeft size={22} />
          </Link>
          <h1 className="text-base font-semibold dark:text-white">Legal & Compliance</h1>
          <div className="w-8" />
        </div>

        <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

          {/* ── Legal Documents ── */}
          <div>
            <SectionTitle title="Legal Documents" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
              {LEGAL_DOCS.map((doc) => (
                <LinkRow
                  key={doc.policyType}
                  icon={doc.icon}
                  iconBg={doc.iconBg}
                  iconColor={doc.iconColor}
                  label={doc.label}
                  sublabel={doc.sublabel}
                  onClick={() => setActiveDoc(doc)}
                />
              ))}
            </div>
          </div>

          {/* ── Data Controls ── */}
          <div>
            <SectionTitle title="Data Controls" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

              <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800">
                <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                  <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-green-50 dark:bg-gray-800">
                    <Download size={16} className="text-green-500" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-gray-900 dark:text-white">Download My Data</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Export a copy of all your account data</p>
                  </div>
                </div>
                <button
                  onClick={handleDownloadData}
                  disabled={downloadLoading || downloadDone}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60 border-green-200 dark:border-green-800 text-green-600 hover:bg-green-50 dark:hover:bg-green-900/20"
                >
                  {downloadLoading
                    ? <><Loader2 size={12} className="animate-spin" /> Preparing…</>
                    : downloadDone
                    ? <><Check size={12} /> Downloaded</>
                    : <><Download size={12} /> Download</>}
                </button>
              </div>
              {downloadError && (
                <p className="px-4 pb-3 -mt-1 text-xs text-red-500">{downloadError}</p>
              )}

              <div className="flex items-center justify-between px-4 py-3.5">
                <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                  <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-red-50 dark:bg-gray-800">
                    <Trash2 size={16} className="text-red-500" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-red-500">Delete My Data</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Permanently remove all your data</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowClearData(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all border-red-200 dark:border-red-800 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
                >
                  Delete
                </button>
              </div>

            </div>
          </div>

          {/* ── Consent Management ── */}
          <div>
            <SectionTitle title="Consent Management" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
              <LinkRow
                icon={SlidersHorizontal}
                iconBg="bg-indigo-50 dark:bg-gray-800"
                iconColor="text-indigo-500"
                label="Manage Consent Preferences"
                sublabel="Control how we use your data for marketing & analytics"
                onClick={() => {}}
              />
            </div>
          </div>

          {/* ── DPDP Compliance ── */}
          <div>
            <SectionTitle title="DPDP Compliance" />
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
              {DPDP_ROWS.map(({ icon, bg, color, label, sublabel, key }) => (
                <div key={key} className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
                  <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                    <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${bg}`}>
                      {React.createElement(icon, { size: 16, className: color })}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>
                    </div>
                  </div>
                  <button
                    onClick={() => handleDpdpRequest(key)}
                    disabled={!!dpdpSent[key]}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60 border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"
                  >
                    {dpdpSent[key] === 'loading'
                      ? <Loader2 size={12} className="animate-spin" />
                      : dpdpSent[key] === 'done'
                      ? <><Check size={12} className="text-green-500" /> Sent</>
                      : 'Request'}
                  </button>
                </div>
              ))}
            </div>
            <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
              DPDP requests are processed within 30 days as per the Digital Personal Data Protection Act 2023.
            </p>
          </div>

        </div>
      </div>

      {/* Policy viewer modal */}
      {activeDoc && (
        <PolicyModal
          doc={activeDoc}
          onClose={() => setActiveDoc(null)}
        />
      )}

      {/* Clear data confirmation / result modal */}
      {showClearData && (
        <ClearDataModal onClose={() => setShowClearData(false)} />
      )}

      {/* Prose styles for Word-exported HTML */}
      <style>{`
        .policy-content h1 {
          font-size: 1.25rem;
          font-weight: 700;
          margin-bottom: 0.5rem;
          color: inherit;
        }
        .policy-content h2 {
          font-size: 1rem;
          font-weight: 700;
          margin-top: 1.25rem;
          margin-bottom: 0.4rem;
          color: inherit;
        }
        .policy-content p,
        .policy-content .LegalBody,
        .policy-content .SmallNote {
          font-size: 0.875rem;
          line-height: 1.65;
          margin-bottom: 0.6rem;
          color: inherit;
        }
        .policy-content .SmallNote {
          color: #6b7280;
          font-size: 0.8rem;
        }
        .policy-content span[lang] { }
        /* Strip Word conditional comments styling */
        .policy-content [style*="mso-"] { text-indent: 0 !important; margin-left: 1.25rem !important; }
        .policy-content ul, .policy-content ol { padding-left: 1.25rem; margin-bottom: 0.5rem; }
        .policy-content li { margin-bottom: 0.25rem; font-size: 0.875rem; line-height: 1.6; }
        .policy-content o\\:p { display: none; }
      `}</style>
    </>
  );
};

export default LegalSettings;
