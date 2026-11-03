import { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { MapPin, ChevronDown, Search, X } from 'lucide-react';
import api from '../lib/api';

// Some callers pass through whatever the API returns, which for location
// fields may be a plain string or an object like { name, lat, lng } —
// coerce either shape down to plain display text.
const toLocationText = (val) => {
  if (!val) return '';
  if (typeof val === 'string') return val;
  if (typeof val === 'object') return val.name || val.display_name || '';
  return String(val);
};

const PANEL_WIDTH  = 340;
const PANEL_HEIGHT = 380; // conservative estimate used to decide open-up vs open-down

// ── Location Selector (trigger + inline dropdown) ───────────────────────────
// Self-managed by default (GPS auto-detect + localStorage + PATCH /users/location),
// matching Home's location bar. Pass `value`/`onChange` to run it as a controlled
// field inside a form instead (e.g. Account Settings) — set `persist={false}` so
// picking a place only updates the field, not the server, until the form is saved.
// The dropdown renders through a portal so it can never be clipped by an
// ancestor's overflow:hidden, and repositions itself (flipping above the
// field when there isn't room below) so it always renders in full.
const LocationSelector = ({
  className = '',
  value,
  onChange,
  autoDetect = true,
  persist = true,
  alignLeft = false,
  placeholder = 'Detecting location...',
}) => {
  const [locationText, setLocationText] = useState(toLocationText(value) || placeholder);
  const [locLoading, setLocLoading]     = useState(autoDetect && value === undefined);
  const [open, setOpen]                 = useState(false);
  const [query, setQuery]               = useState('');
  const [results, setResults]           = useState([]);
  const [searching, setSearching]       = useState(false);
  const [saving, setSaving]             = useState(false);
  const [coords, setCoords]             = useState(null); // { top, left }
  const triggerRef = useRef(null);
  const panelRef   = useRef(null);
  const inputRef   = useRef(null);
  const debounce   = useRef(null);

  const computePosition = () => {
    const rect = triggerRef.current?.getBoundingClientRect();
    if (!rect) return;
    const spaceBelow = window.innerHeight - rect.bottom;
    const openUpward = spaceBelow < PANEL_HEIGHT && rect.top > PANEL_HEIGHT;
    const top = openUpward ? rect.top - PANEL_HEIGHT - 8 : rect.bottom + 8;
    const preferredLeft = alignLeft ? rect.left : rect.right - PANEL_WIDTH;
    const maxLeft = window.innerWidth - PANEL_WIDTH - 12;
    const left = Math.min(Math.max(12, preferredLeft), Math.max(12, maxLeft));
    setCoords({ top, left });
  };

  const toggleOpen = () => {
    if (!open) computePosition();
    setOpen(v => !v);
  };

  // Keep the panel anchored to the trigger while open
  useEffect(() => {
    if (!open) return;
    const reposition = () => computePosition();
    window.addEventListener('resize', reposition);
    window.addEventListener('scroll', reposition, true);
    return () => {
      window.removeEventListener('resize', reposition);
      window.removeEventListener('scroll', reposition, true);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // Close dropdown on outside click — panel lives in a portal, so check both refs
  useEffect(() => {
    const handler = (e) => {
      if (
        triggerRef.current && !triggerRef.current.contains(e.target) &&
        panelRef.current && !panelRef.current.contains(e.target)
      ) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  // Focus search input when dropdown opens
  useEffect(() => {
    if (open) { setQuery(''); setResults([]); setTimeout(() => inputRef.current?.focus(), 50); }
  }, [open]);

  // Stay in sync with an externally controlled value (e.g. a parent form)
  useEffect(() => {
    if (value !== undefined) setLocationText(toLocationText(value) || placeholder);
  }, [value, placeholder]);

  const detectGPS = () => {
    setLocationText('Detecting location...');
    setLocLoading(true);
    if (!navigator.geolocation) {
      setLocationText('Location unavailable');
      setLocLoading(false);
      return;
    }
    navigator.geolocation.getCurrentPosition(
      async ({ coords }) => {
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}`,
            { headers: { 'Accept-Language': 'en' } }
          );
          const data = await res.json();
          const addr = data.address || {};
          const name =
            addr.suburb || addr.neighbourhood || addr.city_district ||
            addr.town || addr.city || addr.county ||
            (data.display_name || '').split(',')[0].trim() || 'Unknown location';
          setLocationText(name);
          if (persist) {
            localStorage.setItem('bsmart_location', name);
            try { await api.patch('/users/location', { name, lat: coords.latitude, lng: coords.longitude }); } catch { /* non-fatal */ }
          }
          onChange?.(name, { lat: coords.latitude, lng: coords.longitude });
        } catch {
          setLocationText('Location unavailable');
        } finally {
          setLocLoading(false);
        }
      },
      () => { setLocationText('Location unavailable'); setLocLoading(false); },
      { timeout: 8000, maximumAge: 300000 }
    );
  };

  // On mount: restore saved location, then GPS as fallback (self-managed mode only)
  useEffect(() => {
    if (!autoDetect) return;
    const saved = localStorage.getItem('bsmart_location');
    if (saved) { setLocationText(saved); setLocLoading(false); }
    else { detectGPS(); }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoDetect]);

  const searchPlaces = async (q) => {
    if (!q.trim()) { setResults([]); return; }
    setSearching(true);
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&limit=7&addressdetails=1`,
        { headers: { 'Accept-Language': 'en' } }
      );
      const data = await res.json();
      setResults(Array.isArray(data) ? data : []);
    } catch { setResults([]); }
    finally { setSearching(false); }
  };

  const handleInput = (e) => {
    const val = e.target.value;
    setQuery(val);
    clearTimeout(debounce.current);
    debounce.current = setTimeout(() => searchPlaces(val), 400);
  };

  const pickResult = async (place) => {
    const addr = place.address || {};
    const name =
      addr.suburb || addr.neighbourhood || addr.city_district ||
      addr.town || addr.city || addr.county ||
      (place.display_name || '').split(',')[0].trim() || 'Unknown location';
    const lat = parseFloat(place.lat);
    const lng = parseFloat(place.lon);

    // Optimistically update UI first
    setLocationText(name);
    setLocLoading(false);
    setOpen(false);
    onChange?.(name, { lat, lng });

    if (persist) {
      localStorage.setItem('bsmart_location', name);
      setSaving(true);
      try {
        await api.patch('/users/location', { name, lat, lng });
      } catch { /* non-fatal — UI already updated */ }
      finally { setSaving(false); }
    }
  };

  const handleUseGPS = () => {
    setOpen(false);
    if (persist) localStorage.removeItem('bsmart_location');
    detectGPS();
  };

  return (
    <div className={`relative w-full ${className}`}>
      {/* Trigger button */}
      <div
        ref={triggerRef}
        onClick={toggleOpen}
        className="flex items-center justify-between gap-2 bg-gray-100 dark:bg-gray-900 px-3 py-2 rounded-lg cursor-pointer hover:bg-gray-200 dark:hover:bg-gray-800 transition-colors w-full"
      >
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <div className="p-1.5 bg-white dark:bg-black rounded-full shadow-sm shrink-0">
            <MapPin size={14} className={locLoading ? 'text-gray-400 animate-pulse' : 'text-red-500'} />
          </div>
          <span className={`text-sm font-bold truncate ${locLoading ? 'text-gray-400 dark:text-gray-500' : 'text-gray-900 dark:text-white'}`}>
            {saving ? 'Saving…' : locationText}
          </span>
        </div>
        <ChevronDown
          size={16}
          className={`text-gray-400 shrink-0 ml-2 transition-transform duration-200 ${open ? 'rotate-180' : ''}`}
        />
      </div>

      {/* Dropdown — portal-rendered so it can't be clipped, anchored to the trigger */}
      {open && coords && createPortal(
        <>
          <div className="fixed inset-0 z-[299]" onClick={() => setOpen(false)} />
          <div
            ref={panelRef}
            style={{ position: 'fixed', top: coords.top, left: coords.left, width: PANEL_WIDTH }}
            className="bg-white dark:bg-[#1c1c1c] rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 z-[300] overflow-hidden"
          >
            {/* Search input */}
            <div className="flex items-center gap-2 px-3 py-2.5 border-b border-gray-100 dark:border-gray-800">
              <Search size={14} className="text-gray-400 shrink-0" />
              <input
                ref={inputRef}
                type="text"
                value={query}
                onChange={handleInput}
                placeholder="Search city, area, neighbourhood…"
                className="flex-1 bg-transparent outline-none text-sm text-gray-900 dark:text-white placeholder-gray-400"
              />
              {searching
                ? <div className="animate-spin rounded-full h-3.5 w-3.5 border-2 border-gray-200 border-t-red-500 shrink-0" />
                : query && <button onClick={() => { setQuery(''); setResults([]); }} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"><X size={13} /></button>
              }
            </div>

            {/* Use GPS */}
            <button
              onClick={handleUseGPS}
              className="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm font-semibold text-blue-500 hover:bg-gray-50 dark:hover:bg-white/5 transition-colors border-b border-gray-100 dark:border-gray-800"
            >
              <MapPin size={14} className="shrink-0" />
              Use my current location
            </button>

            {/* Results list */}
            <div className="max-h-[260px] overflow-y-auto">
              {results.length === 0 && !query.trim() && (
                <p className="px-4 py-5 text-center text-xs text-gray-400">Type to search for a location</p>
              )}
              {results.length === 0 && query.trim() && !searching && (
                <p className="px-4 py-5 text-center text-xs text-gray-400">No results for "{query}"</p>
              )}
              {results.map((place) => {
                const addr  = place.address || {};
                const name  =
                  addr.suburb || addr.neighbourhood || addr.city_district ||
                  addr.town || addr.city || addr.county ||
                  (place.display_name || '').split(',')[0].trim();
                const detail = [addr.city || addr.town, addr.state, addr.country]
                  .filter(Boolean).join(', ');
                return (
                  <button
                    key={place.place_id}
                    onClick={() => pickResult(place)}
                    className="w-full flex items-start gap-3 px-4 py-2.5 hover:bg-gray-50 dark:hover:bg-white/5 transition-colors text-left"
                  >
                    <MapPin size={13} className="text-gray-400 shrink-0 mt-0.5" />
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{name}</p>
                      {detail && <p className="text-[11px] text-gray-400 truncate mt-0.5">{detail}</p>}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </>,
        document.body
      )}
    </div>
  );
};

export default LocationSelector;
