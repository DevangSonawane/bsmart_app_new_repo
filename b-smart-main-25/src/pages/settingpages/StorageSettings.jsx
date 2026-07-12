import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Trash2, HardDrive, Wifi, BarChart3, Image, Video, FileText, Loader2, Check } from 'lucide-react';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const Toggle = ({ on, onChange }) => (
  <label className="relative inline-flex items-center flex-shrink-0 cursor-pointer">
    <input type="checkbox" checked={on} onChange={onChange} className="sr-only peer" />
    <div className={`w-11 h-6 rounded-full transition-colors duration-200 ${on ? 'bg-[#fa3f5e]' : 'bg-gray-300 dark:bg-gray-700'}`} />
    <div className={`absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform duration-200 ${on ? 'translate-x-5' : 'translate-x-0'}`} />
  </label>
);

const StorageSettings = () => {
  const [dataSaver, setDataSaver]       = useState(() => localStorage.getItem('bsmart_data_saver') === 'true');
  const [wifiOnly, setWifiOnly]         = useState(() => localStorage.getItem('bsmart_wifi_only') === 'true');
  const [clearing, setClearing]         = useState(false);
  const [cleared, setCleared]           = useState(false);

  const handleDataSaver = (v) => {
    setDataSaver(v);
    localStorage.setItem('bsmart_data_saver', String(v));
  };

  const handleWifiOnly = (v) => {
    setWifiOnly(v);
    localStorage.setItem('bsmart_wifi_only', String(v));
  };

  const handleClearCache = async () => {
    setClearing(true);
    await new Promise(r => setTimeout(r, 1200));
    setClearing(false);
    setCleared(true);
    setTimeout(() => setCleared(false), 2500);
  };

  const BREAKDOWN = [
    { icon: Image,    label: 'Images',    size: '42.3 MB', color: 'text-blue-500',   bg: 'bg-blue-50 dark:bg-gray-800',   bar: 'bg-blue-400', pct: 55 },
    { icon: Video,    label: 'Videos',    size: '28.1 MB', color: 'text-purple-500', bg: 'bg-purple-50 dark:bg-gray-800', bar: 'bg-purple-400', pct: 36 },
    { icon: FileText, label: 'Documents', size: '7.5 MB',  color: 'text-teal-500',   bg: 'bg-teal-50 dark:bg-gray-800',   bar: 'bg-teal-400',   pct: 9 },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">Storage & Data</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {/* ── Storage ── */}
        <div>
          <SectionTitle title="Storage" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* Clear Cache */}
            <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800">
              <div className="flex items-center gap-3 flex-1">
                <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-red-50 dark:bg-gray-800">
                  <Trash2 size={16} className="text-red-500" />
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-white">Clear Cache</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Free up space used by temporary files</p>
                </div>
              </div>
              <button
                onClick={handleClearCache}
                disabled={clearing || cleared}
                className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60
                  border-red-200 dark:border-red-800 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
              >
                {clearing
                  ? <><Loader2 size={12} className="animate-spin" /> Clearing…</>
                  : cleared
                  ? <><Check size={12} className="text-green-500" /> Cleared</>
                  : 'Clear'}
              </button>
            </div>

            {/* Downloaded Media */}
            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3 flex-1">
                <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-orange-50 dark:bg-gray-800">
                  <HardDrive size={16} className="text-orange-500" />
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-white">Downloaded Media</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">77.9 MB used by downloaded files</p>
                </div>
              </div>
              <span className="text-xs font-bold text-gray-400 dark:text-gray-500">77.9 MB</span>
            </div>

          </div>
        </div>

        {/* ── Data Usage ── */}
        <div>
          <SectionTitle title="Data Usage" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800">
              <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-green-50 dark:bg-gray-800">
                  <BarChart3 size={16} className="text-green-500" />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-gray-900 dark:text-white">Mobile Data Saver</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Reduces media quality on mobile data</p>
                </div>
              </div>
              <Toggle on={dataSaver} onChange={e => handleDataSaver(e.target.checked)} />
            </div>

            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-blue-50 dark:bg-gray-800">
                  <Wifi size={16} className="text-blue-500" />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-gray-900 dark:text-white">Wi-Fi Only Downloads</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Only download media when on Wi-Fi</p>
                </div>
              </div>
              <Toggle on={wifiOnly} onChange={e => handleWifiOnly(e.target.checked)} />
            </div>

          </div>
        </div>

        {/* ── Storage Breakdown ── */}
        <div>
          <SectionTitle title="Storage Breakdown" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            {BREAKDOWN.map(({ icon: Icon, label, size, color, bg, bar, pct }) => (
              <div key={label} className="px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-3">
                    <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${bg}`}>
                      <Icon size={16} className={color} />
                    </div>
                    <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
                  </div>
                  <span className="text-xs font-semibold text-gray-500 dark:text-gray-400">{size}</span>
                </div>
                {/* Progress bar */}
                <div className="ml-12 h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                  <div className={`h-full rounded-full ${bar}`} style={{ width: `${pct}%` }} />
                </div>
              </div>
            ))}
          </div>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
            Total: 77.9 MB · Last updated just now
          </p>
        </div>

      </div>
    </div>
  );
};

export default StorageSettings;
