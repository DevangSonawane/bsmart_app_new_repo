import { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { Calendar as CalendarIcon, ChevronLeft, ChevronRight } from 'lucide-react';

const MONTHS       = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAYS     = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

const PANEL_WIDTH  = 280;
const PANEL_HEIGHT = 380; // conservative estimate (days view is the tallest) used to decide open-up vs open-down

const parseDateStr = (s) => {
  if (!s) return null;
  const [y, m, d] = s.split('-').map(Number);
  if (!y || !m || !d) return null;
  return new Date(y, m - 1, d);
};

const toDateStr = (date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

// dd MMM yyyy — e.g. "31 Jul 1992"
const formatDisplay = (date) =>
  date ? `${String(date.getDate()).padStart(2, '0')} ${MONTHS_SHORT[date.getMonth()]} ${date.getFullYear()}` : '';

const sameDay = (a, b) =>
  a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

// ── Calendar date picker — click-to-open panel with day / month / year views ──
// Rendered through a portal so it can never be clipped by an ancestor's
// overflow:hidden, and repositions itself (flipping above the field when
// there isn't room below) so it always renders in full.
const CalendarDatePicker = ({ value, onChange, placeholder = 'Select date', maxDate, minDate, className = '' }) => {
  const selected = parseDateStr(value);
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const max = maxDate || today;
  const min = minDate || new Date(today.getFullYear() - 120, 0, 1);

  const [open, setOpen]         = useState(false);
  const [viewMode, setViewMode] = useState('days'); // 'days' | 'months' | 'years'
  const [viewDate, setViewDate] = useState(selected || max);
  const [coords, setCoords]     = useState(null); // { top, left, width }
  const triggerRef = useRef(null);
  const panelRef   = useRef(null);

  const computePosition = () => {
    const rect = triggerRef.current?.getBoundingClientRect();
    if (!rect) return;
    const spaceBelow = window.innerHeight - rect.bottom;
    const openUpward = spaceBelow < PANEL_HEIGHT && rect.top > PANEL_HEIGHT;
    const top = openUpward ? rect.top - PANEL_HEIGHT - 8 : rect.bottom + 8;
    const maxLeft = window.innerWidth - PANEL_WIDTH - 12;
    const left = Math.min(Math.max(12, rect.left), Math.max(12, maxLeft));
    setCoords({ top, left });
  };

  const openPicker = () => {
    setViewDate(selected || max);
    setViewMode('days');
    computePosition();
    setOpen(true);
  };

  const closePicker = () => { setOpen(false); setViewMode('days'); };

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
  }, [open]);

  // Close on outside click — panel lives in a portal, so check both refs
  useEffect(() => {
    const handler = (e) => {
      if (
        triggerRef.current && !triggerRef.current.contains(e.target) &&
        panelRef.current && !panelRef.current.contains(e.target)
      ) closePicker();
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const pickDay = (date) => {
    onChange(toDateStr(date));
    closePicker();
  };

  const isDisabled = (date) => date > max || date < min;

  const year  = viewDate.getFullYear();
  const month = viewDate.getMonth();

  // ── Days grid ──
  const firstOfMonth    = new Date(year, month, 1);
  const startWeekday    = firstOfMonth.getDay();
  const daysInMonth     = new Date(year, month + 1, 0).getDate();
  const daysInPrevMonth = new Date(year, month, 0).getDate();

  const cells = [];
  for (let i = 0; i < startWeekday; i++) {
    const d = daysInPrevMonth - startWeekday + 1 + i;
    cells.push({ date: new Date(year, month - 1, d), outside: true });
  }
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ date: new Date(year, month, d), outside: false });
  }
  let nextDay = 1;
  while (cells.length % 7 !== 0) {
    cells.push({ date: new Date(year, month + 1, nextDay), outside: true });
    nextDay++;
  }

  // ── Years grid (12-year page) ──
  const decadeStart = Math.floor(year / 12) * 12;

  return (
    <div className={`relative w-full ${className}`}>
      <button type="button" ref={triggerRef} onClick={openPicker}
        className="w-full flex items-center justify-between gap-2 px-3.5 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-left outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] transition-all">
        <span className={selected ? 'text-gray-900 dark:text-white font-medium' : 'text-gray-400 dark:text-gray-600'}>
          {selected ? formatDisplay(selected) : placeholder}
        </span>
        <CalendarIcon size={15} className="text-gray-400 shrink-0" />
      </button>

      {open && coords && createPortal(
        <>
          {/* Backdrop — closes the popover on outside click */}
          <div className="fixed inset-0 z-[299]" onClick={closePicker} />
          <div
            ref={panelRef}
            style={{ position: 'fixed', top: coords.top, left: coords.left, width: PANEL_WIDTH }}
            className="bg-white dark:bg-[#1c1c1c] rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 z-[300] p-3"
          >
            {/* Header */}
            <div className="flex items-center justify-between mb-2">
              <button type="button" onClick={() => {
                if (viewMode === 'days') setViewDate(new Date(year, month - 1, 1));
                else if (viewMode === 'months') setViewDate(new Date(year - 1, month, 1));
                else setViewDate(new Date(year - 12, month, 1));
              }} className="w-7 h-7 flex items-center justify-center rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500 dark:text-gray-400 transition-colors">
                <ChevronLeft size={15} />
              </button>

              <button type="button" onClick={() => setViewMode(viewMode === 'days' ? 'months' : 'years')}
                className="text-sm font-bold text-gray-900 dark:text-white hover:text-[#fa3f5e] transition-colors px-2 py-1 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800">
                {viewMode === 'days' ? `${MONTHS[month]} ${year}` : viewMode === 'months' ? String(year) : `${decadeStart} – ${decadeStart + 11}`}
              </button>

              <button type="button" onClick={() => {
                if (viewMode === 'days') setViewDate(new Date(year, month + 1, 1));
                else if (viewMode === 'months') setViewDate(new Date(year + 1, month, 1));
                else setViewDate(new Date(year + 12, month, 1));
              }} className="w-7 h-7 flex items-center justify-center rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500 dark:text-gray-400 transition-colors">
                <ChevronRight size={15} />
              </button>
            </div>

            {/* Days view */}
            {viewMode === 'days' && (
              <>
                <div className="grid grid-cols-7 mb-1">
                  {WEEKDAYS.map(w => (
                    <div key={w} className="text-[10px] font-bold text-gray-400 text-center py-1">{w}</div>
                  ))}
                </div>
                <div className="grid grid-cols-7 gap-0.5">
                  {cells.map(({ date, outside }, i) => {
                    const disabled   = isDisabled(date);
                    const isSelected = sameDay(date, selected);
                    const isToday    = sameDay(date, today);
                    return (
                      <button key={i} type="button" disabled={disabled}
                        onClick={() => pickDay(date)}
                        className={`w-9 h-9 flex items-center justify-center rounded-full text-xs font-semibold transition-colors ${
                          isSelected ? 'bg-[#fa3f5e] text-white shadow-sm' :
                          disabled ? 'text-gray-300 dark:text-gray-700 cursor-not-allowed' :
                          outside ? 'text-gray-300 dark:text-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800' :
                          isToday ? 'text-[#fa3f5e] border border-[#fa3f5e]/40 hover:bg-[#fa3f5e]/10' :
                          'text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-800'
                        }`}>
                        {date.getDate()}
                      </button>
                    );
                  })}
                </div>
              </>
            )}

            {/* Months view */}
            {viewMode === 'months' && (
              <div className="grid grid-cols-3 gap-1.5">
                {MONTHS_SHORT.map((m, i) => {
                  const disabled        = new Date(year, i + 1, 0) < min || new Date(year, i, 1) > max;
                  const isSelectedMonth = selected && selected.getFullYear() === year && selected.getMonth() === i;
                  return (
                    <button key={m} type="button" disabled={disabled}
                      onClick={() => { setViewDate(new Date(year, i, 1)); setViewMode('days'); }}
                      className={`py-2.5 rounded-xl text-xs font-bold transition-colors ${
                        isSelectedMonth ? 'bg-[#fa3f5e] text-white' :
                        disabled ? 'text-gray-300 dark:text-gray-700 cursor-not-allowed' :
                        'text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-800'
                      }`}>
                      {m}
                    </button>
                  );
                })}
              </div>
            )}

            {/* Years view */}
            {viewMode === 'years' && (
              <div className="grid grid-cols-3 gap-1.5">
                {Array.from({ length: 12 }, (_, i) => decadeStart + i).map((y) => {
                  const disabled       = y < min.getFullYear() || y > max.getFullYear();
                  const isSelectedYear = selected && selected.getFullYear() === y;
                  return (
                    <button key={y} type="button" disabled={disabled}
                      onClick={() => { setViewDate(new Date(y, month, 1)); setViewMode('months'); }}
                      className={`py-2.5 rounded-xl text-xs font-bold transition-colors ${
                        isSelectedYear ? 'bg-[#fa3f5e] text-white' :
                        disabled ? 'text-gray-300 dark:text-gray-700 cursor-not-allowed' :
                        'text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-800'
                      }`}>
                      {y}
                    </button>
                  );
                })}
              </div>
            )}

            {/* Footer */}
            {viewMode === 'days' && (
              <div className="flex justify-between items-center mt-2 pt-2 border-t border-gray-100 dark:border-gray-800">
                <button type="button" onClick={() => pickDay(today)} disabled={isDisabled(today)}
                  className="text-[11px] font-bold text-[#fa3f5e] hover:underline disabled:opacity-40 disabled:no-underline">
                  Today
                </button>
                {selected && (
                  <button type="button" onClick={() => { onChange(''); closePicker(); }}
                    className="text-[11px] font-semibold text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
                    Clear
                  </button>
                )}
              </div>
            )}
          </div>
        </>,
        document.body
      )}
    </div>
  );
};

export default CalendarDatePicker;
