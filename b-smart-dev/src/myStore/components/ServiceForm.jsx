import React, { useMemo, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { Calendar, MapPin, Globe, Plus, X, Star } from 'lucide-react';
import { addService, updateService } from '../../store/servicesSlice';
import useMediaUploader from '../../hooks/useMediaUploader';
import {
  Stepper, SectionCard, ImageGallery, Dropdown, HighlightsList, CompletenessCard, Checkbox,
  inputCls, labelCls, MAX_IMAGES, MAX_HIGHLIGHTS,
} from '../../components/productForm/ProductFormFields';
import { SERVICE_CATEGORIES, RATE_TYPES, DURATIONS, METHODS, defaultAvailability, servicePrice, isBlankSubservice, validateService, validateSubservices } from '../data/serviceFields';

const STEPS = [
  { label: 'Service Details', subtitle: 'Add basic information' },
  { label: 'Pricing', subtitle: 'Set your rate and duration' },
  { label: 'Availability & Publish', subtitle: 'Location, schedule & publish' },
];

const emptySubservice = () => ({ id: `${Date.now()}-${Math.random().toString(36).slice(2)}`, name: '', hours: '', price: '' });

function SubservicesTable({ subservices, onChange, onRemove, onAdd }) {
  return (
    <div>
      <label className={labelCls}>Subservices</label>
      <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-800">
        <table className="w-full text-sm">
          <thead><tr className="bg-gray-50 dark:bg-gray-900 text-left text-xs font-semibold text-gray-500 dark:text-gray-400"><th className="p-2.5">Service Name</th><th className="p-2.5">Hr</th><th className="p-2.5">Price (₹)</th><th className="p-2.5" /></tr></thead>
          <tbody>
            {subservices.map((subservice, index) => (
              <tr key={subservice.id} className="border-t border-gray-100 dark:border-gray-800">
                <td className="p-2.5 min-w-[180px]"><input aria-label={`Subservice ${index + 1} name`} value={subservice.name} onChange={(event) => onChange(subservice.id, { name: event.target.value })} maxLength={150} placeholder="Service name" className={inputCls} /></td>
                <td className="p-2.5 min-w-[100px]"><input aria-label={`Subservice ${index + 1} hours`} type="number" min="0.01" step="any" value={subservice.hours} onChange={(event) => onChange(subservice.id, { hours: event.target.value })} placeholder="Hr" className={inputCls} /></td>
                <td className="p-2.5 min-w-[120px]"><input aria-label={`Subservice ${index + 1} price`} type="number" min="0" step="0.01" value={subservice.price} onChange={(event) => onChange(subservice.id, { price: event.target.value })} placeholder="0" className={inputCls} /></td>
                <td className="p-2.5"><button type="button" aria-label={`Remove subservice ${index + 1}`} onClick={() => onRemove(subservice.id)} className="text-gray-400 hover:text-red-500"><X size={16} /></button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <button type="button" onClick={onAdd} className="flex items-center gap-1 text-xs font-semibold text-[#fa3f5e] hover:text-insta-purple mt-2"><Plus size={13} /> Add Subservice</button>
    </div>
  );
}

export default function ServiceForm({ service }) {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const [activeStep, setActiveStep] = useState(1);
  const [mainImageIndex, setMainImageIndex] = useState(0);
  const [error, setError] = useState('');
  const errorRef = useRef(null);
  const [form, setForm] = useState(() => ({
    name: service?.name || '', provider: service?.provider || '',
    category: service?.category || SERVICE_CATEGORIES[0], description: service?.description || '',
    price: service ? String(service.price) : '', rateType: service?.rateType || RATE_TYPES[0],
    duration: service?.duration || '1 hour', visible: service?.visible ?? true,
    method: service?.method || METHODS[0], address: service?.address || '',
  }));
  const [highlights, setHighlights] = useState(service?.highlights?.length ? service.highlights : ['', '', '']);
  const [subservices, setSubservices] = useState(() => service?.subservices?.length ? service.subservices.map((item) => ({
    id: item.id || emptySubservice().id,
    name: item.name || '', hours: item.hours == null ? '' : String(item.hours), price: item.price == null ? '' : String(item.price),
  })) : [emptySubservice()]);
  const [availability, setAvailability] = useState(() => service?.availability ? structuredClone(service.availability) : defaultAvailability());
  const uploader = useMediaUploader(service?.images || [], MAX_IMAGES);
  const { images } = uploader;
  const mainIndex = Math.min(mainImageIndex, Math.max(0, images.length - 1));
  const step1Ref = useRef(null);
  const step2Ref = useRef(null);
  const step3Ref = useRef(null);
  const setField = (field, value) => setForm((current) => ({ ...current, [field]: value }));
  const set = (field) => (event) => setField(field, event.target.value);
  const updateSubservice = (id, changes) => setSubservices((current) => current.map((item) => item.id === id ? { ...item, ...changes } : item));
  const removeSubservice = (id) => setSubservices((current) => {
    const next = current.filter((item) => item.id !== id);
    return next.length ? next : [emptySubservice()];
  });
  const addSubservice = () => setSubservices((current) => [...current, emptySubservice()]);
  const goToStep = (step) => {
    setActiveStep(step);
    [step1Ref, step2Ref, step3Ref][step - 1].current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };
  const completeness = useMemo(() => [
    { label: 'Service Details', done: !!(form.name.trim() && form.category && form.description.trim() && images.length) },
    { label: 'Pricing', done: form.price !== '' && Number.isFinite(Number(form.price)) && Number(form.price) >= 0 && !!form.duration && !validateSubservices(subservices) },
    { label: 'Availability & Publish', done: availability.some((day) => day.slots.length) && !validateService(form, availability, true) && (form.method !== 'At my location' || !!form.address.trim()) },
  ], [form, images, availability, subservices]);
  const firstIncomplete = completeness.findIndex((section) => !section.done);
  const autoTarget = firstIncomplete === -1 ? 3 : firstIncomplete + 1;
  const [lastAutoTarget, setLastAutoTarget] = useState(autoTarget);
  if (autoTarget !== lastAutoTarget) {
    setLastAutoTarget(autoTarget);
    if (autoTarget > activeStep) setActiveStep(autoTarget);
  }
  const changeSlots = (day, update) => setAvailability((current) => current.map((entry) => entry.day === day ? { ...entry, slots: update(entry.slots) } : entry));
  const save = (draft) => {
    const message = validateService(form, availability, draft, subservices);
    setError(message);
    if (message) {
      requestAnimationFrame(() => errorRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }));
      return;
    }
    const orderedImages = images.length ? [images[mainIndex], ...images.filter((_, index) => index !== mainIndex)] : [];
    const payload = {
      ...form, name: form.name.trim(), description: form.description.trim(),
      price: Number(form.price) || 0, status: draft ? 'Draft' : 'Published',
      subservices: subservices.filter((item) => !isBlankSubservice(item)).map((item) => ({
        id: item.id, name: item.name.trim(),
        hours: item.hours === '' ? '' : Number(item.hours),
        price: item.price === '' ? '' : Number(item.price),
      })),
      highlights: highlights.filter((value) => value.trim()),
      images: orderedImages.map((image) => image.url), availability,
    };
    dispatch(service ? updateService({ ...payload, id: service.id }) : addService(payload));
    navigate('/market/my-store/services', { state: { serviceTab: draft ? 'Draft' : 'Published' } });
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1280px] ml-auto px-4 pt-6">
      <div className="flex flex-wrap items-center justify-between gap-3 mb-1">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">{service ? 'Edit Service' : 'Add Service'}</h1>
        <div className="flex gap-2">
          <button type="button" onClick={() => save(true)} className="px-4 py-2 rounded-lg text-sm font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-900">Save Draft</button>
          <button type="button" onClick={() => save(false)} className="px-4 py-2 rounded-lg text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">{service?.status === 'Published' ? 'Save Changes' : 'Publish Service'}</button>
        </div>
      </div>
      <Link to="/market/my-store/services" className="text-xs text-gray-400 hover:text-[#fa3f5e]">← Back to My Store</Link>
      {error && <p ref={errorRef} role="alert" className="mt-4 rounded-lg bg-red-50 dark:bg-red-900/20 p-3 text-sm text-red-600 dark:text-red-400">{error}</p>}
      <div className="mt-5"><Stepper active={activeStep} onStepClick={goToStep} steps={STEPS} /></div>
      <div className="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-6 items-start">
        <div className="space-y-4 min-w-0">
          <SectionCard ref={step1Ref} step={1} title="Service Details">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
              <ImageGallery label="Service Images" images={images} mainIndex={mainIndex} onSetMain={setMainImageIndex} onAdd={uploader.handleFileInput} onRemove={uploader.removeImage} fileInputRef={uploader.fileInputRef} onDrop={uploader.handleDrop} onDragOver={uploader.handleDragOver} onDragLeave={uploader.handleDragLeave} isDragging={uploader.isDragging} />
              <div className="space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-1.5"><label htmlFor="service-name" className="text-sm font-medium text-gray-700 dark:text-gray-300">Service Name *</label><span className="text-xs text-gray-400">{form.name.length}/150</span></div>
                  <input id="service-name" value={form.name} onChange={set('name')} maxLength={150} required placeholder="Home Cleaning" className={inputCls} />
                </div>
                <div><label htmlFor="service-provider" className={labelCls}>Provider (optional)</label><input id="service-provider" value={form.provider} onChange={set('provider')} placeholder="Your business name" className={inputCls} /></div>
                <HighlightsList items={highlights} onChange={setHighlights} max={MAX_HIGHLIGHTS} placeholder="e.g. All equipment included" />
              </div>
              <div className="space-y-4">
                <Dropdown label="Category *" value={form.category} options={SERVICE_CATEGORIES} onChange={(value) => setField('category', value)} />
                <div>
                  <div className="flex items-center justify-between mb-1.5"><label htmlFor="service-description" className="text-sm font-medium text-gray-700 dark:text-gray-300">Short Description *</label><span className="text-xs text-gray-400">{form.description.length}/500</span></div>
                  <textarea id="service-description" value={form.description} onChange={set('description')} maxLength={500} rows={4} required placeholder="Describe your service..." className={inputCls} />
                </div>
              </div>
            </div>
          </SectionCard>
          <SectionCard ref={step2Ref} step={2} title="Pricing">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div><label htmlFor="service-price" className={labelCls}>Price (₹) *</label><input id="service-price" type="number" min="0" step="0.01" value={form.price} onChange={set('price')} required placeholder="0" className={inputCls} /></div>
              <Dropdown label="Rate *" value={form.rateType} options={RATE_TYPES} onChange={(value) => setField('rateType', value)} />
              <Dropdown label="Duration *" value={form.duration} options={DURATIONS} onChange={(value) => setField('duration', value)} />
            </div>
            <SubservicesTable subservices={subservices} onChange={updateSubservice} onRemove={removeSubservice} onAdd={addSubservice} />
          </SectionCard>
          <SectionCard ref={step3Ref} step={3} title="Availability & Publish">
            <div>
              <label className={labelCls}>Service method *</label>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                {METHODS.map((method) => <button key={method} type="button" aria-pressed={form.method === method} onClick={() => setField('method', method)} className={`flex flex-col items-center gap-2 px-3 py-3 rounded-lg border text-xs font-medium transition-colors ${form.method === method ? 'border-[#fa3f5e] bg-pink-50 dark:bg-pink-900/10 text-[#fa3f5e]' : 'border-gray-200 dark:border-gray-800 text-gray-500'}`}>{method === 'Online' ? <Globe size={18} /> : <MapPin size={18} />}{method}</button>)}
              </div>
            </div>
            {form.method === 'At my location' && <div><label htmlFor="service-address" className={labelCls}>Service Address *</label><input id="service-address" value={form.address} onChange={set('address')} required placeholder="Where customers should visit" className={inputCls} /></div>}
            <div>
              <label className={labelCls}>Weekly availability</label>
              <div className="divide-y divide-gray-100 dark:divide-gray-800 border border-gray-200 dark:border-gray-800 rounded-lg">
                {availability.map(({ day, slots }) => (
                  <div key={day} className="flex flex-col sm:flex-row sm:items-start gap-2 p-3">
                    <span className="sm:w-24 flex-shrink-0 text-sm font-medium text-gray-700 dark:text-gray-300 sm:pt-2">{day}</span>
                    <div className="flex-1 min-w-0 space-y-2">
                      {!slots.length && <p className="py-2 text-sm text-gray-400">Unavailable</p>}
                      {slots.map((slot, index) => (
                        <div key={index} className="flex items-center gap-2">
                          <input type="time" aria-label={`${day} start time ${index + 1}`} value={slot.start} onChange={(event) => changeSlots(day, (current) => current.map((item, i) => i === index ? { ...item, start: event.target.value } : item))} className={`${inputCls} min-w-0 px-2`} />
                          <span className="text-gray-400">–</span>
                          <input type="time" aria-label={`${day} end time ${index + 1}`} value={slot.end} onChange={(event) => changeSlots(day, (current) => current.map((item, i) => i === index ? { ...item, end: event.target.value } : item))} className={`${inputCls} min-w-0 px-2`} />
                          <button type="button" aria-label={`Remove ${day} slot ${index + 1}`} onClick={() => changeSlots(day, (current) => current.filter((_, i) => i !== index))} className="p-1 text-gray-400 hover:text-red-500"><X size={16} /></button>
                        </div>
                      ))}
                    </div>
                    <button type="button" aria-label={`Add ${day} slot`} onClick={() => changeSlots(day, (current) => [...current, { start: '', end: '' }])} className="self-end sm:self-auto p-2 text-[#fa3f5e] hover:bg-pink-50 dark:hover:bg-gray-800 rounded-lg"><Plus size={16} /></button>
                  </div>
                ))}
              </div>
            </div>
            <Checkbox checked={form.visible} onChange={(value) => setField('visible', value)} label="Visible to customers when published" />
          </SectionCard>
        </div>
        <div className="space-y-4 lg:sticky lg:top-6">
          <div className="border border-gray-200 dark:border-gray-800 rounded-xl p-4">
            <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Listing Preview</h2>
            <div className="w-full aspect-square rounded-lg overflow-hidden bg-gray-50 dark:bg-gray-900 mb-3">{images[mainIndex] && <img src={images[mainIndex].url} alt="Service preview" className="w-full h-full object-cover" />}</div>
            {form.provider && <p className="text-xs font-semibold text-[#fa3f5e] mb-0.5">{form.provider}</p>}
            <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{form.name || 'Service name'}</p>
            <div className="flex items-center gap-1 mt-1 mb-1.5"><Star size={12} className="fill-amber-400 text-amber-400" /><span className="text-xs text-gray-500 dark:text-gray-400">{service ? `${service.bookings} bookings` : 'New listing'}</span></div>
            <p className="font-bold text-gray-900 dark:text-white mb-2">{servicePrice(form)}</p>
            <p className="flex items-center gap-1 text-xs text-green-600 font-medium mb-2"><Calendar size={12} />{form.duration}</p>
            <p className="flex items-center gap-1 text-xs text-gray-500 dark:text-gray-400"><MapPin size={12} />{form.method}</p>
          </div>
          <CompletenessCard sections={completeness} />
        </div>
      </div>
    </div>
  );
}
