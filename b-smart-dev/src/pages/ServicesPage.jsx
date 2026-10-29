import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Store, ChevronRight, ChevronLeft, Search, SlidersHorizontal, X, BadgeCheck, ShieldCheck } from 'lucide-react';
import ServiceIcon from '../myStore/components/ServiceIcon';
import { SERVICE_CATEGORIES, METHODS } from '../myStore/data/serviceFields';
import useMarketplaceWishlist from '../hooks/useMarketplaceWishlist';
import influencerServiceService from '../services/influencerServiceService';
import { ServiceCard } from './Market';
import { Dropdown } from '../components/productForm/ProductFormFields';

const RATING_OPTIONS = ['Any rating', '3+', '4+', '4.5+'];
const SORT_OPTIONS = ['Recommended', 'Price: Low to high', 'Price: High to low', 'Top rated'];

export default function ServicesPage() {
  const { isSaved, toggle } = useMarketplaceWishlist();

  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [methodFilter, setMethodFilter] = useState('All');
  const [sortBy, setSortBy] = useState('Recommended');
  const [minRating, setMinRating] = useState('Any rating');
  const [minPrice, setMinPrice] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const [verifiedOnly, setVerifiedOnly] = useState(false);
  const [filterOpen, setFilterOpen] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(8);

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  }, []);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    influencerServiceService.list()
      .then((items) => { if (alive) { setServices(items); setError(''); } })
      .catch((err) => { if (alive) setError(err?.response?.data?.message || 'Could not load services.'); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, []);

  const listedServices = services.filter((s) => s.status === 'Published' && s.visible);
  const ratingFloor = { 'Any rating': 0, '3+': 3, '4+': 4, '4.5+': 4.5 }[minRating];
  const min = minPrice === '' ? null : Number(minPrice);
  const max = maxPrice === '' ? null : Number(maxPrice);
  const query = search.trim().toLowerCase();

  const filtered = listedServices.filter((s) => {
    const nameFields = [s.name, s.provider, s.description, ...((s.subservices || []).map((sub) => sub.name))];
    const matchesQuery = !query || nameFields.some((value) => String(value ?? '').toLowerCase().includes(query));
    const matchesCategory = categoryFilter === 'All' || s.category === categoryFilter;
    const matchesMethod = methodFilter === 'All' || s.method === methodFilter;
    const matchesRating = Number(s.rating || 0) >= ratingFloor;
    const price = Number(s.price || 0);
    const matchesPrice = (min == null || price >= min) && (max == null || price <= max);
    const matchesVerified = !verifiedOnly || s.seller?.is_verified;
    return matchesQuery && matchesCategory && matchesMethod && matchesRating && matchesPrice && matchesVerified;
  });

  const sorted = [...filtered].sort((a, b) => {
    if (sortBy === 'Price: Low to high') return Number(a.price || 0) - Number(b.price || 0);
    if (sortBy === 'Price: High to low') return Number(b.price || 0) - Number(a.price || 0);
    if (sortBy === 'Top rated') return Number(b.rating || 0) - Number(a.rating || 0);
    return 0;
  });

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const pageItems = sorted.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  const pageNumbers = (() => {
    if (totalPages <= 7) return Array.from({ length: totalPages }, (_, i) => i + 1);
    const pages = new Set([1, 2, currentPage - 1, currentPage, currentPage + 1, totalPages - 1, totalPages]);
    return [...pages].filter((n) => n >= 1 && n <= totalPages).sort((a, b) => a - b);
  })();

  const applySearch = (value) => { setSearch(value); setPage(1); };
  const applyCategoryFilter = (value) => { setCategoryFilter(value); setPage(1); };
  const applyMethodFilter = (value) => { setMethodFilter(value); setPage(1); };
  const applySortBy = (value) => { setSortBy(value); setPage(1); };
  const applyMinRating = (value) => { setMinRating(value); setPage(1); };
  const applyMinPrice = (value) => { setMinPrice(value); setPage(1); };
  const applyMaxPrice = (value) => { setMaxPrice(value); setPage(1); };
  const applyVerifiedOnly = (value) => { setVerifiedOnly(value); setPage(1); };
  const applyPageSize = (value) => { setPageSize(value === 'Show all' ? Math.max(sorted.length, 1) : Number(value)); setPage(1); };

  const activeFilters = [
    categoryFilter !== 'All' ? { key: 'category', label: categoryFilter, onRemove: () => applyCategoryFilter('All') } : null,
    methodFilter !== 'All' ? { key: 'method', label: methodFilter, onRemove: () => applyMethodFilter('All') } : null,
    minRating !== 'Any rating' ? { key: 'rating', label: `Rating: ${minRating}`, onRemove: () => applyMinRating('Any rating') } : null,
    minPrice !== '' ? { key: 'min', label: `Min ₹${minPrice}`, onRemove: () => applyMinPrice('') } : null,
    maxPrice !== '' ? { key: 'max', label: `Max ₹${maxPrice}`, onRemove: () => applyMaxPrice('') } : null,
    verifiedOnly ? { key: 'verified', label: 'Verified talent', onRemove: () => applyVerifiedOnly(false) } : null,
    sortBy !== 'Recommended' ? { key: 'sort', label: sortBy, onRemove: () => applySortBy('Recommended') } : null,
  ].filter(Boolean);

  const clearFilters = () => {
    applyCategoryFilter('All');
    applyMethodFilter('All');
    applyMinRating('Any rating');
    applyMinPrice('');
    applyMaxPrice('');
    applyVerifiedOnly(false);
    applySortBy('Recommended');
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-24 max-w-[1300px] mx-auto px-4 pt-6">
      <div className="flex items-center gap-1.5 text-sm text-gray-500 dark:text-gray-400 mb-4">
        <Link to="/market" className="inline-flex items-center gap-1.5 hover:text-[#fa3f5e]"><Store size={14} /> Marketplace</Link>
        <ChevronRight size={14} />
        <span className="font-semibold text-gray-700 dark:text-gray-300">Services</span>
      </div>

      <section className="rounded-[28px] border border-gray-100 dark:border-gray-800 p-5 sm:p-6 mb-5">
        <div className="flex flex-wrap items-center justify-between gap-5">
          <div className="flex items-center gap-4">
            <span className="w-16 h-16 rounded-2xl flex items-center justify-center shrink-0 bg-pink-50 dark:bg-gray-800">
              <ServiceIcon size={28} className="text-[#fa3f5e]" />
            </span>
            <div>
              <h1 className="text-2xl sm:text-3xl font-extrabold text-gray-900 dark:text-white">Services</h1>
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                {listedServices.length} session{listedServices.length === 1 ? '' : 's'} &amp; consultations from verified creators
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2 text-xs font-semibold text-gray-500 dark:text-gray-400">
            <ShieldCheck size={14} className="text-emerald-500" /> Real availability &amp; pricing, booked directly with the creator
          </div>
        </div>
      </section>

      {/* Category tabs */}
      <div className="mb-4 flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => applyCategoryFilter('All')}
          className={`rounded-full px-4 py-2 text-sm font-semibold transition-colors ${categoryFilter === 'All' ? 'bg-[#fa3f5e] text-white' : 'bg-gray-50 dark:bg-gray-900 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800'}`}
        >
          All Services
        </button>
        {SERVICE_CATEGORIES.map((name) => (
          <button
            key={name}
            type="button"
            onClick={() => applyCategoryFilter(name)}
            className={`rounded-full px-4 py-2 text-sm font-semibold transition-colors ${categoryFilter === name ? 'bg-[#fa3f5e] text-white' : 'bg-gray-50 dark:bg-gray-900 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800'}`}
          >
            {name}
          </button>
        ))}
      </div>

      {/* Toolbar */}
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <div className="relative min-w-0 flex-1">
          <Search size={15} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="search"
            aria-label="Search services"
            placeholder="Search services..."
            value={search}
            onChange={(event) => applySearch(event.target.value)}
            className="h-11 w-full rounded-full border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-900 pl-10 pr-4 text-sm text-gray-900 dark:text-white placeholder:text-gray-400 outline-none focus:border-[#fa3f5e] focus:bg-white dark:focus:bg-gray-900"
          />
        </div>

        <Dropdown className="w-44" value={methodFilter === 'All' ? 'Any delivery' : methodFilter} options={['Any delivery', ...METHODS]} onChange={(option) => applyMethodFilter(option === 'Any delivery' ? 'All' : option)} />

        <button
          type="button"
          onClick={() => applyVerifiedOnly(!verifiedOnly)}
          aria-pressed={verifiedOnly}
          className={`flex h-11 items-center gap-1.5 rounded-full border px-4 text-sm font-semibold transition-colors ${verifiedOnly ? 'border-[#fa3f5e] bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/10' : 'border-gray-100 dark:border-gray-800 text-gray-700 dark:text-gray-300'}`}
        >
          <BadgeCheck size={15} /> Verified talent
        </button>

        <button
          type="button"
          aria-expanded={filterOpen}
          onClick={() => setFilterOpen(true)}
          className={`relative flex h-11 items-center gap-2 rounded-full border px-4 text-sm font-semibold transition-colors ${filterOpen || activeFilters.length ? 'border-[#fa3f5e] bg-pink-50 text-[#fa3f5e] dark:bg-pink-900/10' : 'border-gray-100 dark:border-gray-800 text-gray-700 dark:text-gray-300'}`}
        >
          <SlidersHorizontal size={15} /> Filters
          {activeFilters.length > 0 && <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-[#fa3f5e] px-1.5 text-[10px] font-bold text-white">{activeFilters.length}</span>}
        </button>

        <Dropdown className="w-40" value={sortBy} options={SORT_OPTIONS.map((o) => (o === 'Recommended' ? 'Sort: Recommended' : o))} onChange={(option) => applySortBy(option === 'Sort: Recommended' ? 'Recommended' : option)} />
      </div>

      {activeFilters.length > 0 && (
        <div className="mb-5 flex flex-wrap items-center gap-2">
          <span className="text-[11px] font-bold uppercase tracking-wide text-gray-400">Active:</span>
          {activeFilters.map((filter) => (
            <span key={filter.key} className="flex items-center gap-1.5 rounded-full bg-pink-50 dark:bg-pink-900/10 pl-3 pr-2 py-1 text-[11px] font-semibold text-[#fa3f5e]">
              {filter.label}
              <button type="button" onClick={filter.onRemove} aria-label={`Remove ${filter.label} filter`} className="flex h-4 w-4 items-center justify-center rounded-full hover:bg-pink-100 dark:hover:bg-pink-900/30">
                <X size={11} />
              </button>
            </span>
          ))}
          <button type="button" onClick={clearFilters} className="text-[11px] font-bold text-gray-500 hover:text-[#fa3f5e] dark:text-gray-400 underline underline-offset-2">Clear all</button>
        </div>
      )}

      {error && <p role="alert" className="mb-4 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300">{error}</p>}

      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {Array.from({ length: 8 }, (_, i) => (
            <div key={i} className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
              <div className="aspect-[4/3] animate-pulse bg-gray-100 dark:bg-gray-800" />
              <div className="space-y-3 p-4">
                <div className="h-3 w-20 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
                <div className="h-4 w-3/4 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
                <div className="h-5 w-28 animate-pulse rounded bg-gray-100 dark:bg-gray-800" />
              </div>
            </div>
          ))}
        </div>
      ) : sorted.length === 0 ? (
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 px-4 py-16 text-center shadow-sm">
          <ServiceIcon size={36} className="mx-auto text-[#fa3f5e] mb-4" />
          <p className="text-sm text-gray-500 dark:text-gray-400">No services match your search or filters yet.</p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {pageItems.map((service) => (
              <ServiceCard
                key={service.id}
                service={service}
                isFavorite={isSaved('service', service.id)}
                onToggleFavorite={() => toggle('service', service.id, service)}
              />
            ))}
          </div>

          <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2.5 text-xs text-gray-500 dark:text-gray-400">
              <span>Showing {(currentPage - 1) * pageSize + 1}-{Math.min(currentPage * pageSize, sorted.length)} of {sorted.length}</span>
              <Dropdown
                className="w-28"
                value={pageSize >= sorted.length ? 'Show all' : `${pageSize} / page`}
                options={['8 / page', '16 / page', '32 / page', 'Show all']}
                onChange={(option) => applyPageSize(option === 'Show all' ? 'Show all' : option.split(' ')[0])}
              />
            </div>
            {totalPages > 1 && (
              <div className="flex items-center gap-1.5 rounded-full border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-900 p-1">
                <button type="button" disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)} className="flex h-9 items-center gap-1 rounded-full px-3 text-xs font-semibold text-gray-600 dark:text-gray-300 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white dark:hover:bg-gray-800">
                  <ChevronLeft size={13} /> Prev
                </button>
                {pageNumbers.map((pageNumber, index) => (
                  <React.Fragment key={pageNumber}>
                    {index > 0 && pageNumbers[index - 1] !== pageNumber - 1 && <span className="px-1 text-xs text-gray-400">…</span>}
                    <button
                      type="button"
                      aria-current={pageNumber === currentPage ? 'page' : undefined}
                      onClick={() => setPage(pageNumber)}
                      className={`flex h-9 w-9 items-center justify-center rounded-full text-xs font-bold transition-colors ${pageNumber === currentPage ? 'bg-[#fa3f5e] text-white shadow-sm' : 'text-gray-600 dark:text-gray-300 hover:bg-white dark:hover:bg-gray-800'}`}
                    >
                      {pageNumber}
                    </button>
                  </React.Fragment>
                ))}
                <button type="button" disabled={currentPage === totalPages} onClick={() => setPage(currentPage + 1)} className="flex h-9 items-center gap-1 rounded-full px-3 text-xs font-semibold text-gray-600 dark:text-gray-300 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white dark:hover:bg-gray-800">
                  Next <ChevronRight size={13} />
                </button>
              </div>
            )}
          </div>
        </>
      )}

      {filterOpen && (
        <div className="fixed inset-0 z-[70]">
          <button type="button" aria-label="Close filters" onClick={() => setFilterOpen(false)} className="absolute inset-0 bg-black/35" />
          <aside className="absolute right-0 top-0 flex h-full w-full max-w-[390px] flex-col bg-white shadow-2xl dark:bg-gray-900">
            <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4 dark:border-gray-800">
              <div>
                <h2 className="text-base font-bold text-gray-900 dark:text-white">Filters</h2>
                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Refine service results</p>
              </div>
              <button type="button" onClick={() => setFilterOpen(false)} aria-label="Close filters" className="flex h-9 w-9 items-center justify-center rounded-full border border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800">
                <X size={18} />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-5 py-5 space-y-6">
              <label className="block text-xs font-bold uppercase tracking-wide text-gray-400">
                Minimum rating
                <select value={minRating} onChange={(event) => applyMinRating(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-sm font-semibold normal-case tracking-normal text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white">
                  {RATING_OPTIONS.map((option) => <option key={option} value={option}>{option}</option>)}
                </select>
              </label>
              <div>
                <p className="mb-2 text-xs font-bold uppercase tracking-wide text-gray-400">Price range</p>
                <div className="grid grid-cols-2 gap-2">
                  <input type="number" min="0" value={minPrice} onChange={(event) => applyMinPrice(event.target.value)} placeholder="Min" className="h-11 rounded-xl border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white" />
                  <input type="number" min="0" value={maxPrice} onChange={(event) => applyMaxPrice(event.target.value)} placeholder="Max" className="h-11 rounded-xl border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:border-[#fa3f5e] dark:border-gray-700 dark:bg-gray-900 dark:text-white" />
                </div>
              </div>
              <label className="flex items-center justify-between text-xs font-bold uppercase tracking-wide text-gray-400">
                Verified talent only
                <input type="checkbox" checked={verifiedOnly} onChange={(event) => applyVerifiedOnly(event.target.checked)} className="h-4 w-4 accent-[#fa3f5e]" />
              </label>
            </div>
            <div className="grid grid-cols-2 gap-3 border-t border-gray-100 p-5 dark:border-gray-800">
              <button type="button" onClick={clearFilters} className="rounded-xl border border-gray-200 py-3 text-sm font-bold text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800">Clear</button>
              <button type="button" onClick={() => setFilterOpen(false)} className="rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange py-3 text-sm font-bold text-white">Apply</button>
            </div>
          </aside>
        </div>
      )}
    </div>
  );
}
