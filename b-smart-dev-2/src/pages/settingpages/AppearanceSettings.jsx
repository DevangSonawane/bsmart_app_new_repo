import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Sun, Moon, Monitor, Type, Contrast, Wind, Play } from 'lucide-react';
import { useDispatch, useSelector } from 'react-redux';

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

const Row = ({ icon: Icon, iconBg, iconColor, label, sublabel, right }) => (
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
    <div className="flex-shrink-0">{right}</div>
  </div>
);

const THEMES = [
  { key: 'light',  label: 'Light Mode',      icon: Sun,     color: 'text-yellow-500', bg: 'bg-yellow-50 dark:bg-gray-800' },
  { key: 'dark',   label: 'Dark Mode',       icon: Moon,    color: 'text-indigo-500', bg: 'bg-indigo-50 dark:bg-gray-800' },
  { key: 'system', label: 'System Default',  icon: Monitor, color: 'text-gray-500',   bg: 'bg-gray-100 dark:bg-gray-800' },
];

const FONT_SIZES = ['Small', 'Medium', 'Large'];

const AppearanceSettings = () => {
  const dispatch = useDispatch();
  const { mode } = useSelector((state) => state.theme) || {};

  const [selectedTheme, setSelectedTheme] = useState(mode || 'system');
  const [fontSize, setFontSize]           = useState(() => localStorage.getItem('bsmart_font_size') || 'Medium');
  const [highContrast, setHighContrast]   = useState(() => localStorage.getItem('bsmart_high_contrast') === 'true');
  const [reduceMotion, setReduceMotion]   = useState(() => localStorage.getItem('bsmart_reduce_motion') === 'true');
  const [disableAutoPlay, setDisableAutoPlay] = useState(() => localStorage.getItem('bsmart_disable_autoplay') === 'true');

  const handleTheme = (key) => {
    setSelectedTheme(key);
    try {
      dispatch({ type: 'theme/setMode', payload: key === 'system' ? 'light' : key });
    } catch {}
    if (key === 'dark') {
      document.documentElement.classList.add('dark');
    } else if (key === 'light') {
      document.documentElement.classList.remove('dark');
    } else {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      prefersDark
        ? document.documentElement.classList.add('dark')
        : document.documentElement.classList.remove('dark');
    }
    localStorage.setItem('bsmart_theme', key);
  };

  const handleFontSize = (size) => {
    setFontSize(size);
    localStorage.setItem('bsmart_font_size', size);
    const map = { Small: '14px', Medium: '16px', Large: '18px' };
    document.documentElement.style.fontSize = map[size];
  };

  const handleHighContrast = (v) => {
    setHighContrast(v);
    localStorage.setItem('bsmart_high_contrast', String(v));
    v
      ? document.documentElement.classList.add('high-contrast')
      : document.documentElement.classList.remove('high-contrast');
  };

  const handleReduceMotion = (v) => {
    setReduceMotion(v);
    localStorage.setItem('bsmart_reduce_motion', String(v));
  };

  const handleDisableAutoPlay = (v) => {
    setDisableAutoPlay(v);
    localStorage.setItem('bsmart_disable_autoplay', String(v));
  };

  useEffect(() => {
    const saved = localStorage.getItem('bsmart_theme');
    if (saved) setSelectedTheme(saved);
  }, []);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">Appearance</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {/* ── Theme ── */}
        <div>
          <SectionTitle title="Theme" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            {THEMES.map(({ key, label, icon: Icon, color, bg }) => (
              <button
                key={key}
                onClick={() => handleTheme(key)}
                className="w-full flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${bg}`}>
                    <Icon size={16} className={color} />
                  </div>
                  <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
                </div>
                <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${selectedTheme === key ? 'border-[#fa3f5e]' : 'border-gray-300 dark:border-gray-600'}`}>
                  {selectedTheme === key && <div className="w-2.5 h-2.5 rounded-full bg-[#fa3f5e]" />}
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* ── Accessibility ── */}
        <div>
          <SectionTitle title="Accessibility" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* Font Size */}
            <div className="px-4 py-3.5 border-b border-gray-100 dark:border-gray-800">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-blue-50 dark:bg-gray-800">
                  <Type size={16} className="text-blue-500" />
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-white">Font Size</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Adjust text size across the app</p>
                </div>
              </div>
              <div className="flex gap-2 ml-12">
                {FONT_SIZES.map((size) => (
                  <button
                    key={size}
                    onClick={() => handleFontSize(size)}
                    className={`flex-1 py-2 rounded-xl text-xs font-bold border transition-all ${
                      fontSize === size
                        ? 'bg-[#fa3f5e] text-white border-[#fa3f5e]'
                        : 'bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700'
                    }`}
                  >
                    {size}
                  </button>
                ))}
              </div>
            </div>

            <Row
              icon={Contrast}
              iconBg="bg-purple-50 dark:bg-gray-800"
              iconColor="text-purple-500"
              label="High Contrast Mode"
              sublabel="Increases text and UI contrast"
              right={<Toggle on={highContrast} onChange={e => handleHighContrast(e.target.checked)} />}
            />
          </div>
        </div>

        {/* ── Motion ── */}
        <div>
          <SectionTitle title="Motion" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <Row
              icon={Wind}
              iconBg="bg-teal-50 dark:bg-gray-800"
              iconColor="text-teal-500"
              label="Reduce Motion"
              sublabel="Minimizes animations and transitions"
              right={<Toggle on={reduceMotion} onChange={e => handleReduceMotion(e.target.checked)} />}
            />
            <Row
              icon={Play}
              iconBg="bg-orange-50 dark:bg-gray-800"
              iconColor="text-orange-500"
              label="Disable Auto Play"
              sublabel="Videos and reels won't play automatically"
              right={<Toggle on={disableAutoPlay} onChange={e => handleDisableAutoPlay(e.target.checked)} />}
            />
          </div>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
            Changes are saved instantly to your device.
          </p>
        </div>

      </div>
    </div>
  );
};

export default AppearanceSettings;
