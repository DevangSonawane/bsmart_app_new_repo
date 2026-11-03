import React, { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { useFloating, autoUpdate, offset, flip, shift } from '@floating-ui/react-dom';
import { HexColorPicker } from 'react-colorful';
import { ChevronDown, ChevronUp, ImagePlus, GripVertical, X, Plus, Check } from 'lucide-react';

export const CATEGORIES = ['Fashion', 'Tech', 'Home', 'Beauty'];
export const STATUS_OPTIONS = ['Draft', 'Active', 'Out of Stock'];
export const RETURN_POLICY_OPTIONS = ['7 Days Replacement', '10 Days Return', '15 Days Return', 'No Returns'];
export const WARRANTY_OPTIONS = ['None', '3 Months Manufacturer Warranty', '6 Months Manufacturer Warranty', '1 Year Manufacturer Warranty'];
export const COUNTRY_OPTIONS = ['India', 'China', 'USA', 'Other'];
export const WEIGHT_UNITS = ['kg', 'g', 'lb', 'oz'];
export const MAX_IMAGES = 10;
export const MAX_HIGHLIGHTS = 5;
export const SWATCHES = [
  { name: 'Brown', hex: '#8B5E3C' },
  { name: 'Black', hex: '#111111' },
  { name: 'Tan',   hex: '#C9A27E' },
  { name: 'Beige', hex: '#E8DCC8' },
  { name: 'Red',   hex: '#E24C4C' },
  { name: 'Blue',  hex: '#3B6FE2' },
];

// [appearance:textfield] + the two webkit rules hide the native number-input
// spin buttons — the field still only accepts numbers, just without the arrows.
export const inputCls = "w-full px-3.5 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] dark:text-white [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none";
export const labelCls = "text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5 block";

// ─── Stepper ────────────────────────────────────────────────────────────────────
export const Stepper = ({ steps, active, onStepClick }) => (
  <div className="flex items-center mb-6">
    {steps.map((step, i) => (
      <React.Fragment key={step.label}>
        <button
          type="button"
          onClick={() => onStepClick(i + 1)}
          className="flex items-center gap-2.5 text-left"
        >
          <span
            className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 ${
              i + 1 <= active ? 'bg-[#fa3f5e] text-white' : 'bg-white dark:bg-gray-900 border-2 border-gray-300 dark:border-gray-700 text-gray-400'
            }`}
          >
            {i + 1}
          </span>
          <span className="hidden sm:block">
            <span className={`block text-sm font-semibold ${i + 1 === active ? 'text-[#fa3f5e]' : 'text-gray-700 dark:text-gray-300'}`}>
              {step.label}
            </span>
            <span className="block text-xs text-gray-400 dark:text-gray-500">{step.subtitle}</span>
          </span>
        </button>
        {i < steps.length - 1 && <div className="flex-1 border-t-2 border-dotted border-gray-200 dark:border-gray-800 mx-4" />}
      </React.Fragment>
    ))}
  </div>
);

// ─── Numbered, collapsible section card ────────────────────────────────────────
export const SectionCard = React.forwardRef(({ step, title, children, defaultOpen = true }, ref) => {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div ref={ref} className="border border-gray-200 dark:border-gray-800 rounded-xl bg-white dark:bg-gray-950 overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-5 py-4"
      >
        <h2 className="text-base font-bold text-gray-900 dark:text-white">{step}. {title}</h2>
        {open ? <ChevronUp size={18} className="text-gray-400" /> : <ChevronDown size={18} className="text-gray-400" />}
      </button>
      {open && <div className="px-5 pb-5 space-y-4">{children}</div>}
    </div>
  );
});
SectionCard.displayName = 'SectionCard';

// ─── Color picker: swatch button opens a react-colorful popover ───────────────
// `value` is a hex string (e.g. "#8B5E3C"), not a preset name — pick any color.
// The popover renders through a portal into document.body so it can't be
// clipped by a scrollable ancestor (e.g. the variants table's overflow-x-auto).
export const ColorPicker = ({ value, onChange }) => {
  const [open, setOpen] = useState(false);
  const [hexInput, setHexInput] = useState(value);
  const popoverRef = useRef(null);

  const { refs, floatingStyles } = useFloating({
    open,
    onOpenChange: setOpen,
    placement: 'bottom-start',
    whileElementsMounted: autoUpdate,
    middleware: [offset(4), flip(), shift({ padding: 8 })],
  });

  useEffect(() => { setHexInput(value); }, [value]);

  useEffect(() => {
    if (!open) return undefined;
    const handler = (e) => {
      if (refs.reference.current?.contains?.(e.target)) return;
      if (popoverRef.current?.contains(e.target)) return;
      setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open, refs.reference]);

  const commitHex = (raw) => {
    const hex = raw.startsWith('#') ? raw : `#${raw}`;
    if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(hex)) onChange(hex);
  };

  return (
    <>
      <button
        ref={refs.setReference}
        type="button"
        onClick={() => setOpen((o) => !o)}
        title={value}
        className="w-9 h-9 rounded-lg border border-gray-200 dark:border-gray-700 flex-shrink-0"
        style={{ backgroundColor: value }}
      />
      {open && createPortal(
        <div
          ref={(node) => { refs.setFloating(node); popoverRef.current = node; }}
          style={floatingStyles}
          className="p-3 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-lg shadow-xl z-50 w-48"
        >
          <HexColorPicker color={value} onChange={onChange} style={{ width: '100%', height: 140 }} />
          <input
            value={hexInput}
            onChange={(e) => setHexInput(e.target.value)}
            onBlur={(e) => commitHex(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') commitHex(e.target.value); }}
            placeholder="#8B5E3C"
            className="w-full mt-2 px-2 py-1.5 text-xs font-mono bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] dark:text-white"
          />
          <div className="flex flex-wrap gap-1.5 mt-2">
            {SWATCHES.map((s) => (
              <button
                key={s.name}
                type="button"
                title={s.name}
                onClick={() => onChange(s.hex)}
                className={`w-6 h-6 rounded-full flex-shrink-0 border border-black/10 transition-all ${
                  value.toLowerCase() === s.hex.toLowerCase() ? 'ring-2 ring-offset-1 ring-[#fa3f5e] dark:ring-offset-gray-900' : 'hover:scale-110'
                }`}
                style={{ backgroundColor: s.hex }}
              />
            ))}
          </div>
        </div>,
        document.body
      )}
    </>
  );
};

// ─── Checkbox ───────────────────────────────────────────────────────────────────
export const Checkbox = ({ checked, onChange, label }) => (
  <label className="flex items-center gap-2 cursor-pointer select-none">
    <input
      type="checkbox"
      checked={checked}
      onChange={(e) => onChange(e.target.checked)}
      className="w-4 h-4 rounded border-gray-300 dark:border-gray-700 text-[#fa3f5e] accent-[#fa3f5e] focus:ring-2 focus:ring-[#fa3f5e]/30"
    />
    {label && <span className="text-sm text-gray-700 dark:text-gray-300">{label}</span>}
  </label>
);

// ─── Dimensions: Length x Width x Height, each with a "cm" unit ────────────────
export const DimensionsInput = ({ length, width, height, onChange }) => (
  <div>
    <label className={labelCls}>Dimensions (L x W x H) *</label>
    <div className="grid grid-cols-3 gap-2">
      {[
        { key: 'length', value: length, placeholder: 'L' },
        { key: 'width', value: width, placeholder: 'W' },
        { key: 'height', value: height, placeholder: 'H' },
      ].map(({ key, value, placeholder }) => (
        <div key={key} className="relative">
          <input
            type="number" min="0" step="0.1"
            value={value}
            onChange={(e) => onChange(key, e.target.value)}
            required
            placeholder={placeholder}
            className={`${inputCls} pr-8`}
          />
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 pointer-events-none">cm</span>
        </div>
      ))}
    </div>
  </div>
);

// Best-effort parse of a legacy "32 x 24 x 12 cm" / "32cm x 24cm x 12cm" style
// string back into three numbers, for editing products created before this field split.
export const parseDimensions = (str) => {
  const nums = (str || '').match(/[\d.]+/g) || [];
  return { length: nums[0] || '', width: nums[1] || '', height: nums[2] || '' };
};

// Best-effort parse of a legacy "0.75" (plain number) or "0.75 kg" (value + unit)
// package weight back into its two parts, for editing products created before the unit split.
export const parseWeight = (raw) => {
  const str = String(raw ?? '');
  const match = str.match(/^([\d.]+)\s*([a-zA-Z]*)/);
  const value = match?.[1] || '';
  const unit = match?.[2]?.toLowerCase();
  return { value, unit: WEIGHT_UNITS.includes(unit) ? unit : 'kg' };
};

// ─── Custom dropdown ────────────────────────────────────────────────────────────
export const Dropdown = ({ label, value, options, onChange, className = '', labelClassName = labelCls }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  return (
    <div className={className}>
      {label && <label className={labelClassName}>{label}</label>}
      <div ref={ref} className="relative">
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          className={`w-full flex items-center justify-between px-3.5 py-2.5 bg-white dark:bg-gray-900 border rounded-lg text-sm text-left transition-all ${
            open ? 'border-[#fa3f5e] ring-2 ring-[#fa3f5e]/20' : 'border-gray-200 dark:border-gray-800'
          }`}
        >
          <span className="text-gray-900 dark:text-white truncate">{value}</span>
          <ChevronDown size={16} className={`text-gray-400 transition-transform flex-shrink-0 ${open ? 'rotate-180' : ''}`} />
        </button>
        {open && (
          <div className="absolute top-full left-0 right-0 mt-1 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-lg shadow-xl z-20 overflow-hidden max-h-56 overflow-y-auto">
            {options.map((opt) => (
              <button
                key={opt}
                type="button"
                onClick={() => { onChange(opt); setOpen(false); }}
                className={`w-full text-left px-3.5 py-2.5 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 ${
                  value === opt ? 'text-[#fa3f5e] font-semibold bg-pink-50 dark:bg-gray-800' : 'text-gray-700 dark:text-gray-200'
                }`}
              >
                {opt}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// ─── Package weight: number + selectable unit (kg / g / lb / oz) ──────────────
export const WeightInput = ({ value, unit, onValueChange, onUnitChange }) => (
  <div>
    <label className={labelCls}>Package Weight *</label>
    <div className="flex gap-2">
      <input
        type="number" min="0" step="0.01"
        value={value}
        onChange={(e) => onValueChange(e.target.value)}
        required
        placeholder="0"
        className={inputCls}
      />
      <Dropdown className="w-20 flex-shrink-0" value={unit} options={WEIGHT_UNITS} onChange={onUnitChange} />
    </div>
  </div>
);

// ─── Key Highlights (max N, reorder handle is decorative) ─────────────────────
export const HighlightsList = ({ items, onChange, max = MAX_HIGHLIGHTS, placeholder = 'e.g. Premium full-grain leather for durability' }) => {
  const update = (i, val) => onChange(items.map((h, idx) => (idx === i ? val : h)));
  const remove = (i) => onChange(items.filter((_, idx) => idx !== i));
  const add = () => onChange([...items, '']);

  return (
    <div>
      <div className="flex items-center justify-between mb-1.5">
        <label className={labelCls.replace('mb-1.5 block', '')}>Key Highlights *</label>
      </div>
      <div className="space-y-2">
        {items.map((h, i) => (
          <div key={i} className="flex items-center gap-2">
            <GripVertical size={14} className="text-gray-300 dark:text-gray-600 flex-shrink-0" />
            <input
              value={h}
              onChange={(e) => update(i, e.target.value)}
              placeholder={placeholder}
              className={inputCls}
            />
            <button type="button" onClick={() => remove(i)} className="text-gray-400 hover:text-red-500 flex-shrink-0">
              <X size={16} />
            </button>
          </div>
        ))}
      </div>
      {items.length < max && (
        <div className="flex items-center gap-2 mt-2">
          <button type="button" onClick={add} className="flex items-center gap-1 text-xs font-semibold text-[#fa3f5e] hover:text-insta-purple">
            <Plus size={13} /> Add Highlight
          </button>
          <span className="text-xs text-gray-400 dark:text-gray-500">(Max {max})</span>
        </div>
      )}
    </div>
  );
};

// ─── Variants — color + size definition (Product Details section) ─────────────
export const emptyVariant = () => ({
  id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  color: SWATCHES[0].hex,
  size: '',
  stock: '',
  price: '',
});

// ─── Variants pricing table (Price & Inventory section) ────────────────────────
export const VariantsPricingTable = ({ variants, onChange, onRemove, onAdd }) => (
  <div>
    <label className={labelCls}>Variants (optional)</label>
    <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-800">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-gray-50 dark:bg-gray-900 text-left text-xs font-semibold text-gray-500 dark:text-gray-400">
            <th className="p-2.5">Color</th>
            <th className="p-2.5">Size</th>
            <th className="p-2.5">Stock Quantity</th>
            <th className="p-2.5">Price (₹)</th>
            <th className="p-2.5" />
          </tr>
        </thead>
        <tbody>
          {variants.map((v) => (
              <tr key={v.id} className="border-t border-gray-100 dark:border-gray-800">
                <td className="p-2.5">
                  <ColorPicker value={v.color} onChange={(color) => onChange(v.id, { color })} />
                </td>
                <td className="p-2.5 min-w-[110px]">
                  <input value={v.size} onChange={(e) => onChange(v.id, { size: e.target.value })} placeholder="One Size" className={inputCls} />
                </td>
                <td className="p-2.5 min-w-[110px]">
                  <input type="number" min="0" value={v.stock} onChange={(e) => onChange(v.id, { stock: e.target.value })} placeholder="0" className={inputCls} />
                </td>
                <td className="p-2.5 min-w-[110px]">
                  <input type="number" min="0" step="1" value={v.price} onChange={(e) => onChange(v.id, { price: e.target.value })} placeholder="0" className={inputCls} />
                </td>
                <td className="p-2.5">
                  <button type="button" onClick={() => onRemove(v.id)} className="text-gray-400 hover:text-red-500">
                    <X size={16} />
                  </button>
                </td>
              </tr>
          ))}
        </tbody>
      </table>
    </div>
    <button type="button" onClick={onAdd} className="flex items-center gap-1 text-xs font-semibold text-[#fa3f5e] hover:text-insta-purple mt-2">
      <Plus size={13} /> Add Variant
    </button>
  </div>
);

// ─── Product image gallery: main preview + thumbnail strip ─────────────────────
export const ImageGallery = ({ images, mainIndex, onSetMain, onAdd, onRemove, fileInputRef, onDrop, onDragOver, onDragLeave, isDragging, label = 'Product Images *' }) => (
  <div>
    <label className={labelCls}>{label}</label>
    <div
      onDrop={onDrop}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      className={`rounded-xl border-2 border-dashed overflow-hidden ${isDragging ? 'border-[#fa3f5e] bg-pink-50 dark:bg-gray-900' : 'border-gray-200 dark:border-gray-800'}`}
    >
      <button
        type="button"
        onClick={() => fileInputRef.current?.click()}
        className="w-full aspect-square bg-gray-50 dark:bg-gray-900 flex items-center justify-center relative"
      >
        {images.length > 0 ? (
          <>
            <img src={images[mainIndex]?.url} alt="" className="w-full h-full object-cover" />
            <span className="absolute bottom-2 left-1/2 -translate-x-1/2 px-2 py-0.5 rounded-full bg-black/60 text-white text-[10px] font-semibold">Main</span>
          </>
        ) : (
          <span className="flex flex-col items-center gap-2 text-gray-400">
            <ImagePlus size={28} />
            <span className="text-xs font-medium">Click or drag images here</span>
          </span>
        )}
        <input ref={fileInputRef} type="file" accept="image/*" multiple className="hidden" onChange={onAdd} />
      </button>
    </div>
    {images.length > 0 && (
      <div className="flex gap-2 mt-2 overflow-x-auto pb-1">
        {images.map((img, i) => (
          <div key={img.id} className="relative flex-shrink-0">
            <button
              type="button"
              onClick={() => onSetMain(i)}
              className={`w-14 h-14 rounded-lg overflow-hidden border-2 ${i === mainIndex ? 'border-[#fa3f5e]' : 'border-transparent'}`}
            >
              <img src={img.url} alt="" className="w-full h-full object-cover" />
            </button>
            <button
              type="button"
              onClick={() => onRemove(img.id)}
              className="absolute -top-1.5 -right-1.5 w-4 h-4 rounded-full bg-black/70 text-white flex items-center justify-center"
            >
              <X size={10} />
            </button>
          </div>
        ))}
      </div>
    )}
  </div>
);

// ─── Listing completeness checklist ────────────────────────────────────────────
export const CompletenessCard = ({ sections }) => {
  const doneCount = sections.filter((s) => s.done).length;
  const pct = Math.round((doneCount / sections.length) * 100);

  return (
    <div className="border border-gray-200 dark:border-gray-800 rounded-xl p-4">
      <div className="flex items-center justify-between mb-2">
        <h2 className="text-sm font-bold text-gray-900 dark:text-white">Listing completeness</h2>
        <span className="text-sm font-bold text-[#fa3f5e]">{pct}%</span>
      </div>
      <div className="w-full h-1.5 rounded-full bg-gray-100 dark:bg-gray-800 mb-4 overflow-hidden">
        <div className="h-full bg-[#fa3f5e] transition-all" style={{ width: `${pct}%` }} />
      </div>
      <div className="space-y-2 mb-3">
        {sections.map((s) => (
          <div key={s.label} className="flex items-center gap-2 text-sm">
            <span className={`w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0 ${s.done ? 'bg-green-500' : 'bg-gray-200 dark:bg-gray-700'}`}>
              {s.done && <Check size={11} className="text-white" />}
            </span>
            <span className={s.done ? 'text-gray-700 dark:text-gray-300' : 'text-gray-400 dark:text-gray-500'}>{s.label}</span>
          </div>
        ))}
      </div>
      {pct === 100 && (
        <p className="text-xs text-amber-700 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 rounded-lg px-3 py-2">
          Great! Your listing is complete and ready to publish.
        </p>
      )}
    </div>
  );
};
