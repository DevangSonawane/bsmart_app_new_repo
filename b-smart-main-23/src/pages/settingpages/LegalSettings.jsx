import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, FileText, Shield, RefreshCw, BookOpen, Download, Trash2, SlidersHorizontal, Database, Edit3, XCircle, Loader2, Check, ChevronRight } from 'lucide-react';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const LinkRow = ({ icon: Icon, iconBg, iconColor, label, sublabel, href, onClick, danger }) => (
  <div
    role={onClick || href ? 'button' : undefined}
    tabIndex={onClick || href ? 0 : undefined}
    onClick={onClick}
    className={`flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0 transition-colors ${onClick || href ? 'cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800' : ''}`}
  >
    <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        <Icon size={16} className={iconColor} />
      </div>
      <div className="min-w-0">
        <p className={`text-sm font-medium ${danger ? 'text-red-500' : 'text-gray-900 dark:text-white'}`}>{label}</p>
        {sublabel && <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>}
      </div>
    </div>
    {href
      ? <a href={href} target="_blank" rel="noopener noreferrer" className="flex-shrink-0"><ChevronRight size={16} className="text-gray-400" /></a>
      : onClick ? <ChevronRight size={16} className="text-gray-400 flex-shrink-0" /> : null
    }
  </div>
);

const LEGAL_DOCS = [
  { icon: FileText, bg: 'bg-blue-50 dark:bg-gray-800',   color: 'text-blue-500',   label: 'Terms & Conditions',    sublabel: 'Usage rules and policies',          href: 'https://bebsmart.in/terms' },
  { icon: Shield,   bg: 'bg-pink-50 dark:bg-gray-800',   color: 'text-[#fa3f5e]',  label: 'Privacy Policy',        sublabel: 'How we collect and use your data',  href: 'https://bebsmart.in/privacy' },
  { icon: RefreshCw,bg: 'bg-orange-50 dark:bg-gray-800', color: 'text-orange-500', label: 'Refund Policy',         sublabel: 'Coin & transaction refund rules',    href: 'https://bebsmart.in/refund' },
  { icon: BookOpen, bg: 'bg-teal-50 dark:bg-gray-800',   color: 'text-teal-500',   label: 'Community Guidelines',  sublabel: 'Standards for a safe community',    href: 'https://bebsmart.in/guidelines' },
];

const DPDP_ROWS = [
  { icon: Database, bg: 'bg-blue-50 dark:bg-gray-800',   color: 'text-blue-500',   label: 'Data Access Request',     sublabel: 'Request a copy of your data',    key: 'access' },
  { icon: Edit3,    bg: 'bg-yellow-50 dark:bg-gray-800', color: 'text-yellow-600', label: 'Data Correction Request', sublabel: 'Request to correct inaccurate data', key: 'correction' },
  { icon: XCircle,  bg: 'bg-red-50 dark:bg-gray-800',    color: 'text-red-500',    label: 'Data Deletion Request',   sublabel: 'Request permanent removal of your data', key: 'deletion' },
];

const LegalSettings = () => {
  const [downloadLoading, setDownloadLoading] = useState(false);
  const [downloadDone, setDownloadDone]       = useState(false);
  const [dpdpSent, setDpdpSent]               = useState({});

  const handleDownloadData = async () => {
    setDownloadLoading(true);
    await new Promise(r => setTimeout(r, 1500));
    setDownloadLoading(false);
    setDownloadDone(true);
    setTimeout(() => setDownloadDone(false), 3000);
  };

  const handleDpdpRequest = async (key) => {
    setDpdpSent(p => ({ ...p, [key]: 'loading' }));
    await new Promise(r => setTimeout(r, 1200));
    setDpdpSent(p => ({ ...p, [key]: 'done' }));
    setTimeout(() => setDpdpSent(p => { const n = { ...p }; delete n[key]; return n; }), 3000);
  };

  return (
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
            {LEGAL_DOCS.map(({ icon, bg, color, label, sublabel, href }) => (
              <LinkRow key={label} icon={icon} iconBg={bg} iconColor={color} label={label} sublabel={sublabel} href={href} />
            ))}
          </div>
        </div>

        {/* ── Data Controls ── */}
        <div>
          <SectionTitle title="Data Controls" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* Download My Data */}
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
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60
                  border-green-200 dark:border-green-800 text-green-600 hover:bg-green-50 dark:hover:bg-green-900/20"
              >
                {downloadLoading
                  ? <><Loader2 size={12} className="animate-spin" /> Preparing…</>
                  : downloadDone
                  ? <><Check size={12} /> Sent</>
                  : 'Request'}
              </button>
            </div>

            {/* Delete My Data */}
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
              <button className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all
                border-red-200 dark:border-red-800 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20">
                Request
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
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60
                    border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"
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
  );
};

export default LegalSettings;
