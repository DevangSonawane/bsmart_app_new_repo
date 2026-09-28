import React, { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Image, Video, FileText, Loader2, Check, AlertCircle, RefreshCw } from 'lucide-react';
import api from '../../lib/api';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const Toggle = ({ on, onChange, disabled }) => (
  <label className={`relative inline-flex items-center flex-shrink-0 ${disabled ? 'cursor-not-allowed opacity-60' : 'cursor-pointer'}`}>
    <input type="checkbox" checked={on} onChange={onChange} disabled={disabled} className="sr-only peer" />
    <div className={`w-11 h-6 rounded-full transition-colors duration-200 ${on ? 'bg-[#fa3f5e]' : 'bg-gray-300 dark:bg-gray-700'}`} />
    <div className={`absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform duration-200 ${on ? 'translate-x-5' : 'translate-x-0'}`} />
  </label>
);

const DEFAULT_SETTINGS = {
  auto_download_images:    true,
  auto_download_videos:    false,
  auto_download_documents: false,
};

const MEDIA_ROWS = [
  {
    key:      'auto_download_images',
    label:    'Auto Download Images',
    sublabel: 'Automatically save received images to your device',
    icon:     Image,
    iconBg:   'bg-blue-50 dark:bg-gray-800',
    iconColor:'text-blue-500',
  },
  {
    key:      'auto_download_videos',
    label:    'Auto Download Videos',
    sublabel: 'Automatically save received videos (uses more data)',
    icon:     Video,
    iconBg:   'bg-purple-50 dark:bg-gray-800',
    iconColor:'text-purple-500',
  },
  {
    key:      'auto_download_documents',
    label:    'Auto Download Documents',
    sublabel: 'Automatically save received documents and files',
    icon:     FileText,
    iconBg:   'bg-teal-50 dark:bg-gray-800',
    iconColor:'text-teal-500',
  },
];

const MessagingSettings = () => {
  const [settings, setSettings]       = useState(DEFAULT_SETTINGS);
  const [pageLoading, setPageLoading] = useState(true);
  const [pageError, setPageError]     = useState('');
  const [savingKey, setSavingKey]     = useState(null);   // which key is being saved
  const [savedKey, setSavedKey]       = useState(null);   // which key just saved
  const [saveError, setSaveError]     = useState('');
  const savedTimer = useRef(null);

  // ── fetch on mount ──────────────────────────────────────────────
  const fetchSettings = async () => {
    setPageLoading(true);
    setPageError('');
    try {
      const res  = await api.get('/settings/messaging');
      const data = res.data?.settings || res.data || {};
      setSettings({ ...DEFAULT_SETTINGS, ...data });
    } catch (e) {
      setPageError(e?.response?.data?.message || 'Failed to load settings. Please try again.');
    } finally {
      setPageLoading(false);
    }
  };

  useEffect(() => { fetchSettings(); }, []);

  // ── optimistic toggle + auto-save ──────────────────────────────
  const handleToggle = async (key, checked) => {
    // Optimistic update
    const prev = settings[key];
    setSettings(p => ({ ...p, [key]: checked }));
    setSaveError('');
    setSavingKey(key);

    try {
      const res  = await api.patch('/settings/messaging', { [key]: checked });
      const saved = res.data?.settings || {};
      // Sync server response if provided
      if (Object.keys(saved).length > 0) {
        setSettings(p => ({ ...p, ...saved }));
      }

      // Show tick briefly
      setSavedKey(key);
      clearTimeout(savedTimer.current);
      savedTimer.current = setTimeout(() => setSavedKey(null), 2000);
    } catch (e) {
      // Revert on failure
      setSettings(p => ({ ...p, [key]: prev }));
      setSaveError(e?.response?.data?.message || 'Failed to save. Try again.');
    } finally {
      setSavingKey(null);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* ── Header ── */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">Messaging</h1>
        <button
          onClick={fetchSettings}
          disabled={pageLoading}
          className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 disabled:opacity-50 transition-colors"
        >
          <RefreshCw size={16} className={pageLoading ? 'animate-spin' : ''} />
        </button>
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {/* ── Save error banner ── */}
        {saveError && (
          <div className="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
            <AlertCircle size={14} className="shrink-0" />
            <span className="flex-1">{saveError}</span>
            <button onClick={() => setSaveError('')} className="text-red-400 hover:text-red-600">✕</button>
          </div>
        )}

        {/* ── Page loading ── */}
        {pageLoading ? (
          <div className="flex flex-col items-center justify-center py-24 gap-3">
            <Loader2 size={28} className="animate-spin text-gray-300 dark:text-gray-700" />
            <span className="text-sm text-gray-400">Loading settings…</span>
          </div>

        ) : pageError ? (
          <div className="flex flex-col items-center justify-center py-20 gap-3">
            <AlertCircle size={28} className="text-red-400" />
            <p className="text-sm text-gray-500 dark:text-gray-400 text-center">{pageError}</p>
            <button
              onClick={fetchSettings}
              className="flex items-center gap-1.5 px-4 py-2 rounded-xl bg-[#fa3f5e] text-white text-sm font-semibold"
            >
              <RefreshCw size={14} /> Retry
            </button>
          </div>

        ) : (
          <>
            {/* ── Media Settings ── */}
            <div>
              <SectionTitle title="Media Settings" />
              <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
                {MEDIA_ROWS.map(({ key, label, sublabel, icon: Icon, iconBg, iconColor }) => (
                  <div
                    key={key}
                    className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0"
                  >
                    <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
                        <Icon size={16} className={iconColor} />
                      </div>
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
                        <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>
                      </div>
                    </div>

                    {/* Indicator + toggle */}
                    <div className="flex items-center gap-2 flex-shrink-0">
                      {savingKey === key && (
                        <Loader2 size={13} className="animate-spin text-gray-400" />
                      )}
                      {savedKey === key && savingKey !== key && (
                        <Check size={13} className="text-green-500" />
                      )}
                      <Toggle
                        on={settings[key]}
                        disabled={savingKey === key}
                        onChange={e => handleToggle(key, e.target.checked)}
                      />
                    </div>
                  </div>
                ))}
              </div>

              <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
                Changes are saved automatically. Auto-downloading on mobile data may increase usage.
              </p>
            </div>
          </>
        )}

      </div>
    </div>
  );
};

export default MessagingSettings;
