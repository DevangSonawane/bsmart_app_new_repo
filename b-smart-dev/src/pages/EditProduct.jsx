import React, { useState, useMemo, useRef } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Star, Truck } from 'lucide-react';
import { updateProduct } from '../store/productsSlice';
import useMediaUploader from '../hooks/useMediaUploader';
import {
  CATEGORIES, STATUS_OPTIONS, RETURN_POLICY_OPTIONS, WARRANTY_OPTIONS, COUNTRY_OPTIONS,
  MAX_IMAGES, MAX_HIGHLIGHTS, inputCls, labelCls,
  Stepper, SectionCard, Checkbox, Dropdown, HighlightsList, DimensionsInput, parseDimensions,
  VariantsPricingTable, ImageGallery, CompletenessCard,
  emptyVariant, WeightInput, parseWeight,
} from '../components/productForm/ProductFormFields';

const EditProduct = () => {
  const { productId } = useParams();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const product = useSelector((state) => state.products.items.find((p) => String(p.id) === String(productId)));

  const [activeStep, setActiveStep] = useState(1);
  const [mainImageIndex, setMainImageIndex] = useState(0);
  const [form, setForm] = useState(() => ({
    name: product?.name || '',
    brand: product?.vendor || '',
    category: product?.category || 'Fashion',
    shortDescription: product?.description || '',
    mrp: product?.mrp ? String(product.mrp) : (product ? String(product.price) : ''),
    sellingPrice: product ? String(product.price) : '',
    stockQuantity: product?.stockQuantity != null ? String(product.stockQuantity) : '',
    sku: product?.sku || '',
    trackInventory: product?.trackInventory ?? true,
    status: product?.status || 'Draft',
    ...(() => {
      const { value, unit } = parseWeight(product?.packageWeight);
      return { packageWeight: value, weightUnit: unit };
    })(),
    ...(() => {
      const { length, width, height } = parseDimensions(product?.dimensions);
      return { dimLength: length, dimWidth: width, dimHeight: height };
    })(),
    dispatchTime: product?.dispatchTime || '',
    hsnGst: product?.hsnGst || '',
    countryOfOrigin: product?.countryOfOrigin || 'India',
    useStoreDelivery: product?.useStoreDelivery ?? true,
    returnPolicy: product?.returnPolicy || RETURN_POLICY_OPTIONS[0],
    useStoreReturnPolicy: product?.useStoreReturnPolicy ?? true,
    warranty: product?.warranty || WARRANTY_OPTIONS[0],
  }));
  const [highlights, setHighlights] = useState(product?.highlights?.length ? product.highlights : ['', '', '']);
  const [variants, setVariants] = useState(product?.variants?.length ? product.variants : [emptyVariant()]);
  const {
    images, isDragging, fileInputRef,
    handleFileInput, handleDrop, handleDragOver, handleDragLeave, removeImage,
  } = useMediaUploader(product?.images || [], MAX_IMAGES);

  const step1Ref = useRef(null);
  const step2Ref = useRef(null);
  const step3Ref = useRef(null);
  const stepRefs = { 1: step1Ref, 2: step2Ref, 3: step3Ref };

  if (!product) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-3">
        <p className="text-gray-500 dark:text-gray-400">Product not found.</p>
        <Link to="/market/my-store/products" className="text-[#fa3f5e] font-semibold text-sm">Back to My Store</Link>
      </div>
    );
  }

  const set = (field) => (e) => setForm((f) => ({ ...f, [field]: e.target.value }));
  const setField = (field, value) => setForm((f) => ({ ...f, [field]: value }));

  const updateVariant = (id, changes) => setVariants((v) => v.map((x) => (x.id === id ? { ...x, ...changes } : x)));
  const removeVariant = (id) => setVariants((v) => {
    const next = v.filter((x) => x.id !== id);
    return next.length ? next : [emptyVariant()];
  });
  const addVariant = () => setVariants((v) => [...v, emptyVariant()]);

  const discountPct = useMemo(() => {
    const mrp = parseInt(form.mrp, 10);
    const sp = parseInt(form.sellingPrice, 10);
    if (!mrp || !sp || sp >= mrp) return 0;
    return Math.round((1 - sp / mrp) * 100);
  }, [form.mrp, form.sellingPrice]);

  const goToStep = (n) => {
    setActiveStep(n);
    stepRefs[n]?.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const completeness = useMemo(() => ([
    { label: 'Product Details', done: !!(form.name && form.category && form.shortDescription && images.length) },
    { label: 'Price & Inventory', done: !!(form.mrp && form.sellingPrice && form.stockQuantity && form.sku) },
    { label: 'Delivery & Publish', done: !!(form.packageWeight && form.dimLength && form.dimWidth && form.dimHeight && form.dispatchTime) },
  ]), [form, images]);

  // Auto-advance the stepper forward as each section is completed. Never moves
  // backward on its own, so manually reviewing an earlier step isn't undone.
  const nextIncompleteStep = completeness.findIndex((s) => !s.done);
  const autoTargetStep = nextIncompleteStep === -1 ? completeness.length : nextIncompleteStep + 1;
  const [lastAutoTarget, setLastAutoTarget] = useState(autoTargetStep);
  if (autoTargetStep !== lastAutoTarget && autoTargetStep > activeStep) {
    setLastAutoTarget(autoTargetStep);
    setActiveStep(autoTargetStep);
  }

  const buildPayload = (status) => ({
    id: product.id,
    name: form.name,
    vendor: form.brand,
    category: form.category,
    description: form.shortDescription,
    price: parseInt(form.sellingPrice, 10) || 0,
    mrp: parseInt(form.mrp, 10) || 0,
    stockQuantity: parseInt(form.stockQuantity, 10) || 0,
    sku: form.sku,
    trackInventory: form.trackInventory,
    status,
    packageWeight: form.packageWeight ? `${form.packageWeight} ${form.weightUnit}` : '',
    dimensions: (form.dimLength && form.dimWidth && form.dimHeight) ? `${form.dimLength} x ${form.dimWidth} x ${form.dimHeight} cm` : '',
    dispatchTime: form.dispatchTime,
    hsnGst: form.hsnGst,
    countryOfOrigin: form.countryOfOrigin,
    useStoreDelivery: form.useStoreDelivery,
    returnPolicy: form.returnPolicy,
    useStoreReturnPolicy: form.useStoreReturnPolicy,
    warranty: form.warranty,
    highlights: highlights.filter(Boolean),
    images: images.map((img) => img.url),
    variants: variants.map((v) => ({
      ...v,
      stock: parseInt(v.stock, 10) || 0,
      price: parseInt(v.price, 10) || 0,
    })),
  });

  const handleSaveDraft = (e) => {
    e.preventDefault();
    dispatch(updateProduct(buildPayload('Draft')));
    navigate('/market/my-store/products');
  };

  const handlePublish = (e) => {
    e.preventDefault();
    dispatch(updateProduct(buildPayload(form.status === 'Draft' ? 'Active' : form.status)));
    navigate('/market/my-store/products');
  };

  const stockNum = parseInt(form.stockQuantity, 10) || 0;

  return (
     <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1280px] ml-auto px-4 pt-6">
      <div className="flex items-center justify-between mb-1">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Edit Product</h1>
        <div className="flex gap-2">
          <button
            onClick={handleSaveDraft}
            className="px-4 py-2 rounded-lg text-sm font-bold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-900"
          >
            Save Draft
          </button>
          <button
            onClick={handlePublish}
            className="px-4 py-2 rounded-lg text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
          >
            Publish Product
          </button>
        </div>
      </div>
      <Link to="/market/my-store/products" className="text-xs text-gray-400 hover:text-[#fa3f5e]">← Back to My Store</Link>

      <div className="mt-5">
        <Stepper
          active={activeStep}
          onStepClick={goToStep}
          steps={[
            { label: 'Product Details', subtitle: 'Add basic information' },
            { label: 'Price & Inventory', subtitle: 'Set pricing and stock' },
            { label: 'Delivery & Publish', subtitle: 'Delivery, returns & publish' },
          ]}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-6 items-start">
        {/* Main column */}
        <div className="space-y-4 min-w-0">
          <SectionCard ref={step1Ref} step={1} title="Product Details">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
              <ImageGallery
                images={images}
                mainIndex={mainImageIndex}
                onSetMain={setMainImageIndex}
                onAdd={handleFileInput}
                onRemove={removeImage}
                fileInputRef={fileInputRef}
                onDrop={handleDrop}
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                isDragging={isDragging}
              />

              <div className="space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Product Name *</label>
                    <span className="text-xs text-gray-400">{form.name.length}/150</span>
                  </div>
                  <input value={form.name} onChange={set('name')} maxLength={150} required placeholder="Classic Brown Leather Tote" className={inputCls} />
                </div>
                <div>
                  <label className={labelCls}>Brand (optional)</label>
                  <input value={form.brand} onChange={set('brand')} placeholder="UrbanHide" className={inputCls} />
                </div>
                <HighlightsList items={highlights} onChange={setHighlights} max={MAX_HIGHLIGHTS} />
              </div>

              <div className="space-y-4">
                <Dropdown label="Category *" value={form.category} options={CATEGORIES} onChange={(v) => setField('category', v)} />
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Short Description *</label>
                    <span className="text-xs text-gray-400">{form.shortDescription.length}/500</span>
                  </div>
                  <textarea value={form.shortDescription} onChange={set('shortDescription')} maxLength={500} rows={4} required placeholder="Describe your product..." className={inputCls} />
                </div>
              </div>
            </div>
          </SectionCard>

          <SectionCard ref={step2Ref} step={2} title="Price & Inventory">
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-4">
              <div>
                <label className={labelCls}>MRP (₹) *</label>
                <input type="number" min="0" step="1" value={form.mrp} onChange={set('mrp')} required placeholder="0" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Selling Price (₹) *</label>
                <input type="number" min="0" step="1" value={form.sellingPrice} onChange={set('sellingPrice')} required placeholder="0" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Discount</label>
                <div className={`${inputCls} bg-gray-50 dark:bg-gray-800 text-gray-500 select-none cursor-default`}>
                  {discountPct ? `${discountPct}%` : '—'}
                </div>
              </div>
              <div>
                <label className={labelCls}>Stock Quantity *</label>
                <input type="number" min="0" value={form.stockQuantity} onChange={set('stockQuantity')} required placeholder="0" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Seller SKU *</label>
                <input value={form.sku} onChange={set('sku')} required placeholder="SKU-001" className={inputCls} />
              </div>
            </div>

            <div className="flex flex-wrap items-end gap-6">
              <div>
                <label className={labelCls}>Track Inventory</label>
                <Checkbox checked={form.trackInventory} onChange={(v) => setField('trackInventory', v)} />
              </div>
              <Dropdown className="flex-1 min-w-[180px]" label="Product Status *" value={form.status} options={STATUS_OPTIONS} onChange={(v) => setField('status', v)} />
            </div>

            <VariantsPricingTable variants={variants} onChange={updateVariant} onRemove={removeVariant} onAdd={addVariant} />
          </SectionCard>

          <SectionCard ref={step3Ref} step={3} title="Delivery & Publish">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <WeightInput
                value={form.packageWeight}
                unit={form.weightUnit}
                onValueChange={(v) => setField('packageWeight', v)}
                onUnitChange={(v) => setField('weightUnit', v)}
              />
              <DimensionsInput
                length={form.dimLength}
                width={form.dimWidth}
                height={form.dimHeight}
                onChange={(key, value) => setField(key === 'length' ? 'dimLength' : key === 'width' ? 'dimWidth' : 'dimHeight', value)}
              />
              <div>
                <label className={labelCls}>Dispatch Time *</label>
                <input value={form.dispatchTime} onChange={set('dispatchTime')} required placeholder="1-2 Days" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>HSN / GST (optional)</label>
                <input value={form.hsnGst} onChange={set('hsnGst')} placeholder="4202" className={inputCls} />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Dropdown label="Country of Origin *" value={form.countryOfOrigin} options={COUNTRY_OPTIONS} onChange={(v) => setField('countryOfOrigin', v)} />
                <Checkbox checked={form.useStoreDelivery} onChange={(v) => setField('useStoreDelivery', v)} label="Use store delivery settings" />
              </div>
              <div className="space-y-2">
                <Dropdown label="Return Policy *" value={form.returnPolicy} options={RETURN_POLICY_OPTIONS} onChange={(v) => setField('returnPolicy', v)} />
                <Checkbox checked={form.useStoreReturnPolicy} onChange={(v) => setField('useStoreReturnPolicy', v)} label="Use store return policy" />
              </div>
            </div>

            <Dropdown label="Warranty (optional)" value={form.warranty} options={WARRANTY_OPTIONS} onChange={(v) => setField('warranty', v)} />
          </SectionCard>
        </div>

        {/* Right sidebar */}
        <div className="space-y-4 lg:sticky lg:top-6">
          <div className="border border-gray-200 dark:border-gray-800 rounded-xl p-4">
            <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Listing Preview</h2>
            <div className="w-full aspect-square rounded-lg overflow-hidden bg-gray-50 dark:bg-gray-900 mb-3">
              {images[mainImageIndex] && <img src={images[mainImageIndex].url} alt="" className="w-full h-full object-cover" />}
            </div>
            {form.brand && <p className="text-xs font-semibold text-[#fa3f5e] mb-0.5">{form.brand}</p>}
            <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{form.name || 'Product name'}</p>
            <div className="flex items-center gap-1 mt-1 mb-1.5">
              <Star size={12} className="fill-amber-400 text-amber-400" />
              <span className="text-xs text-gray-500 dark:text-gray-400">
                {product.rating > 0 ? `${product.rating} (${product.reviews})` : 'New listing'}
              </span>
            </div>
            <div className="flex items-center gap-2 mb-1">
              <span className="font-bold text-gray-900 dark:text-white">₹{form.sellingPrice || '0'}</span>
              {discountPct > 0 && (
                <>
                  <span className="text-xs text-gray-400 line-through">₹{form.mrp}</span>
                  <span className="text-xs font-semibold text-green-600">{discountPct}% off</span>
                </>
              )}
            </div>
            {form.stockQuantity !== '' && stockNum <= 10 && (
              <p className="text-xs font-semibold text-red-500 mb-1">Only {stockNum} left</p>
            )}
            <p className="flex items-center gap-1 text-xs text-green-600 font-medium mb-2">
              <Truck size={12} /> Free delivery
            </p>
            {variants.length > 0 && (
              <div className="flex items-center gap-1.5">
                {[...new Set(variants.map((v) => v.color))].map((color) => (
                  <span key={color} className="w-5 h-5 rounded-full border border-gray-200 dark:border-gray-700" style={{ backgroundColor: color }} title={color} />
                ))}
              </div>
            )}
          </div>

          <CompletenessCard sections={completeness} />
        </div>
      </div>
    </div>
  );
};

export default EditProduct;
