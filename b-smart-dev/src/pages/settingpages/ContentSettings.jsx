import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  ArrowLeft, Loader2, Check, AlertCircle, Play, Zap, Hash, Sparkles,
} from 'lucide-react';
import api from '../../lib/api';

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

const ToggleRow = ({ label, sublabel, icon: Icon, iconBg, iconColor, on, onChange }) => (
  <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
    <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        <Icon size={16} className={iconColor} />
      </div>
      <div className="min-w-0">
        <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
        {sublabel && <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>}
      </div>
    </div>
    <Toggle on={on} onChange={onChange} />
  </div>
);

const INTEREST_OPTIONS = [
  'Technology', 'Fashion', 'Food', 'Travel', 'Sports', 'Music',
  'Art', 'Gaming', 'Health', 'Business', 'Finance', 'Education',
  'Comedy', 'News', 'Fitness', 'Beauty', 'Movies', 'Photography',
];

const TOPIC_OPTIONS = [
  'Trending', 'Local', 'World News', 'Science', 'Politics',
  'Environment', 'Culture', 'DIY', 'Pets', 'Parenting',
];

const DEFAULT = {
  autoplay_videos: true,
  autoplay_pulse: true,
  interests: [],
  topics: [],
};

const ContentSettings = () => {
  const [settings, setSettings]   = useState(DEFAULT);
  const [loading, setLoading]     = useState(true);
  const [saving, setSaving]       = useState(false);
  const [saved, setSaved]         = useState(false);
  const [isDirty, setIsDirty]     = useState(false);
  const [error, setError]         = useState('');

  useEffect(() => {
    api.get('/settings/content')
      .then(res => {
        const d = res.data?.settings || res.data || {};
        setSettings({ ...DEFAULT, ...d });
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const upd = (key, val) => {
    setSettings(p => ({ ...p, [key]: val }));
    setIsDirty(true);
    setSaved(false);
  };

  const toggleChip = (key, item) => {
    setSettings(p => {
      const list = p[key] || [];
      const next = list.includes(item) ? list.filter(i => i !== item) : [...list, item];
      return { ...p, [key]: next };
    });
    setIsDirty(true);
    setSaved(false);
  };

  const handleSave = async () => {
    setSaving(true); setError('');
    try {
      await api.patch('/settings/content', settings);
      setIsDirty(false);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to save. Try again.');
    } finally { setSaving(false); }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></Link>
        <h1 className="text-base font-semibold dark:text-white">Content Preferences</h1>
        {isDirty ? (
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#fa3f5e] text-white text-sm font-bold disabled:opacity-60 hover:opacity-90 transition-opacity"
          >
            {saving ? <><Loader2 size={13} className="animate-spin" /> Saving…</> : saved ? <><Check size={13} /> Saved!</> : 'Save'}
          </button>
        ) : (
          <div className="w-16 flex items-center justify-end">
            {saved && <span className="text-xs text-green-500 font-semibold flex items-center gap-1"><Check size={12} /> Saved</span>}
          </div>
        )}
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {error && (
          <div className="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
            <AlertCircle size={14} className="shrink-0" /> {error}
          </div>
        )}

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 size={26} className="animate-spin text-gray-300 dark:text-gray-700" />
          </div>
        ) : (
          <>
            {/* ── Feed Preferences ─────────────────────────── */}
            <div>
              <SectionTitle title="Feed Preferences" />

              {/* Select Interests */}
              <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm p-4 mb-3">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-8 h-8 rounded-full bg-indigo-50 dark:bg-gray-800 flex items-center justify-center">
                    <Sparkles size={15} className="text-indigo-500" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-900 dark:text-white">Select Interests</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400">Personalise what you see in your feed</p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  {INTEREST_OPTIONS.map(item => {
                    const active = (settings.interests || []).includes(item);
                    return (
                      <button
                        key={item}
                        onClick={() => toggleChip('interests', item)}
                        className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-all ${
                          active
                            ? 'bg-[#fa3f5e] text-white border-[#fa3f5e] shadow-sm'
                            : 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-[#fa3f5e] hover:text-[#fa3f5e]'
                        }`}
                      >
                        {item}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Follow Topics */}
              <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm p-4">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-8 h-8 rounded-full bg-orange-50 dark:bg-gray-800 flex items-center justify-center">
                    <Hash size={15} className="text-orange-500" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-900 dark:text-white">Follow Topics</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400">Choose topics you want to follow</p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  {TOPIC_OPTIONS.map(item => {
                    const active = (settings.topics || []).includes(item);
                    return (
                      <button
                        key={item}
                        onClick={() => toggleChip('topics', item)}
                        className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-all ${
                          active
                            ? 'bg-[#fa3f5e] text-white border-[#fa3f5e] shadow-sm'
                            : 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-[#fa3f5e] hover:text-[#fa3f5e]'
                        }`}
                      >
                        {item}
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>

            {/* ── Video Preferences ────────────────────────── */}
            <div>
              <SectionTitle title="Video Preferences" />
              <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
                <ToggleRow
                  label="Auto Play Videos"
                  sublabel="Videos in your feed play automatically as you scroll"
                  icon={Play}
                  iconBg="bg-rose-50 dark:bg-gray-800"
                  iconColor="text-[#fa3f5e]"
                  on={settings.autoplay_videos}
                  onChange={e => upd('autoplay_videos', e.target.checked)}
                />
                <ToggleRow
                  label="Auto Play Pulse"
                  sublabel="Pulse reels play automatically as you browse"
                  icon={Zap}
                  iconBg="bg-amber-50 dark:bg-gray-800"
                  iconColor="text-amber-500"
                  on={settings.autoplay_pulse}
                  onChange={e => upd('autoplay_pulse', e.target.checked)}
                />
              </div>
              <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
                Disabling autoplay can save data when on mobile networks.
              </p>
            </div>
          </>
        )}

      </div>
    </div>
  );
};

export default ContentSettings;
