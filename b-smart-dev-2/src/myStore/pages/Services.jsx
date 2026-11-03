import ServiceIcon from '../components/ServiceIcon';
import React, { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { AlertCircle, Plus, Search, Pencil, Calendar, Trash2, Eye, EyeOff } from 'lucide-react';
import { Dropdown } from '../../components/productForm/ProductFormFields';
import { servicePrice } from '../data/serviceFields';
import influencerServiceService from '../../services/influencerServiceService';
import RowActionsMenu from '../components/RowActionsMenu';
import CatalogRowSkeleton from '../components/CatalogRowSkeleton';

const PAGE_SIZE = 7;

export default function StoreServices() {
  const location = useLocation();
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState(location.state?.serviceTab === 'Draft' ? 'Draft' : 'Published');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('All status');
  const [page, setPage] = useState(1);

  useEffect(() => {
    let alive = true;
    influencerServiceService.listMine()
      .then((items) => {
        if (!alive) return;
        setServices(items);
        setError('');
      })
      .catch((err) => {
        if (alive) setError(err?.response?.data?.message || 'Could not load your services.');
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => { alive = false; };
  }, []);

  const patchService = async (id, changes) => {
    try {
      const updated = await influencerServiceService.update(id, changes);
      setServices((items) => items.map((item) => String(item.id) === String(id) ? { ...item, ...updated } : item));
      setError('');
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not update this service.');
    }
  };

  const deleteService = async (id, name) => {
    if (!window.confirm(`Remove "${name}" from your store?`)) return;
    try {
      await influencerServiceService.remove(id);
      setServices((items) => items.filter((item) => String(item.id) !== String(id)));
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not delete this service.');
    }
  };

  const filtered = services.filter((service) => {
    const visible = service.status === 'Published' && service.visible;
    return service.status === tab && service.name.toLowerCase().includes(search.trim().toLowerCase())
      && (status === 'All status' || (status === 'Visible' ? visible : !visible));
  });
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * PAGE_SIZE;
  return (
    <div className="max-w-[1280px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className="flex items-center justify-between gap-3 mb-5">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">My Services</h1>
        <Link to="/market/add-service" className="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-colors"><Plus size={16} /> Add Service</Link>
      </div>
      {error && <div className="mb-4 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300"><AlertCircle size={15} className="shrink-0" /> {error}</div>}
      <div className="flex gap-5 border-b border-gray-200 dark:border-gray-800 mb-4">
        {['Published', 'Draft'].map((value) => <button type="button" key={value} onClick={() => { setTab(value); setPage(1); }} aria-pressed={tab === value} className={`pb-2.5 px-2 text-sm font-semibold border-b-2 transition-colors ${tab === value ? 'border-[#fa3f5e] text-gray-900 dark:text-white' : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`}>{value === 'Draft' ? 'Drafts' : value}</button>)}
      </div>
      <div className="flex flex-wrap gap-3 mb-5">
        <div className="relative flex-1 min-w-[180px] sm:max-w-md">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input aria-label="Search services" value={search} onChange={(event) => { setSearch(event.target.value); setPage(1); }} placeholder="Search services" className="w-full pl-9 pr-3 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] dark:text-white" />
        </div>
        <Dropdown className="w-44" value={status} options={['All status', 'Visible', 'Hidden']} onChange={(value) => { setStatus(value); setPage(1); }} />
      </div>
      <div className="overflow-x-auto rounded-2xl border border-gray-100 bg-white p-3 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <table className="w-full min-w-[900px] table-fixed border-separate border-spacing-y-3 text-sm">
          <colgroup>
            <col className="w-[48%]" />
            <col className="w-[12%]" />
            <col className="w-[15%]" />
            <col className="w-[16%]" />
            <col className="w-[9%]" />
          </colgroup>
          <thead><tr className="text-left text-xs font-semibold text-gray-400 dark:text-gray-500">
            {['Service', 'Price', 'Bookings', 'Visibility', 'Actions'].map((heading) => <th key={heading} className={`px-5 py-3.5 font-medium ${heading === 'Actions' ? 'text-right' : ''}`}>{heading}</th>)}
          </tr></thead>
          <tbody>
            {loading && Array.from({ length: PAGE_SIZE }, (_, i) => <CatalogRowSkeleton key={i} />)}
            {!loading && filtered.slice(start, start + PAGE_SIZE).map((service) => {
              const visible = service.status === 'Published' && service.visible;
              return <tr key={service.id}>
                <td className="rounded-l-xl border-y border-l border-gray-100 bg-white px-4 py-3 dark:border-gray-800 dark:bg-gray-900"><div className="flex items-start gap-3.5">
                  <div className="w-24 h-24 rounded-xl overflow-hidden flex-shrink-0 bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">
                    {service.images?.[0] ? <img src={service.images[0]} alt="" className="w-full h-full object-cover" /> : <ServiceIcon size={28} className="text-[#fa3f5e]" />}
                  </div>
                  <div className="min-w-0 flex-1 py-1">
                    <span className="mb-1 inline-flex rounded-full bg-pink-50 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-[#fa3f5e] dark:bg-pink-900/20">
                      {service.category || 'Service'}
                    </span>
                    <Link to={`/market/service/${service.id}?from=services`} className="block whitespace-normal break-words text-[15px] font-bold leading-snug text-gray-900 transition-colors hover:text-[#fa3f5e] dark:text-white">{service.name || 'Untitled service'}</Link>
                    <p className="mt-1 line-clamp-2 text-xs leading-5 text-gray-400 dark:text-gray-500">{service.shortDescription || service.description || service.provider || 'Influencer service'}</p>
                    <p className="mt-1.5 flex items-center gap-1.5 text-xs font-medium text-gray-400"><Calendar size={12} />{service.bookings} bookings</p>
                  </div>
                </div></td>
                <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle font-semibold text-gray-800 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-200 whitespace-nowrap">{servicePrice(service)}</td>
                <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle text-gray-500 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-400">{service.bookings}</td>
                <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle dark:border-gray-800 dark:bg-gray-900"><button type="button" disabled={service.status === 'Draft'} aria-label={`${visible ? 'Hide' : 'Show'} ${service.name}`} onClick={() => patchService(service.id, { visible_to_customers: !service.visible })} className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${visible ? 'bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400' : 'bg-gray-100 text-gray-500 dark:bg-gray-800'}`}><span className={`w-1.5 h-1.5 rounded-full ${visible ? 'bg-green-500' : 'bg-gray-400'}`} />{visible ? 'Visible' : 'Hidden'}</button></td>
                <td className="rounded-r-xl border-y border-r border-gray-100 bg-white px-4 py-3 text-right align-middle dark:border-gray-800 dark:bg-gray-900">
                  <RowActionsMenu ariaLabel={`Actions for ${service.name}`}>
                    {(close) => (
                      <>
                        <Link role="menuitem" to={`/market/service/${service.id}?from=services`} onClick={close} className="flex items-center gap-2 px-3.5 py-2 text-xs font-semibold text-gray-600 hover:bg-gray-50 hover:text-[#fa3f5e] dark:text-gray-300 dark:hover:bg-gray-800">
                          View service
                        </Link>
                        <Link role="menuitem" to={`/market/edit-service/${service.id}`} onClick={close} className="flex items-center gap-2 px-3.5 py-2 text-xs font-semibold text-gray-600 hover:bg-gray-50 hover:text-[#fa3f5e] dark:text-gray-300 dark:hover:bg-gray-800">
                          <Pencil size={13} /> Edit
                        </Link>
                        {service.status === 'Published' && (
                          <button type="button" role="menuitem" onClick={() => { patchService(service.id, { visible_to_customers: !service.visible }); close(); }} className="flex w-full items-center gap-2 px-3.5 py-2 text-left text-xs font-semibold text-gray-600 hover:bg-gray-50 hover:text-[#fa3f5e] dark:text-gray-300 dark:hover:bg-gray-800">
                            {visible ? <EyeOff size={13} /> : <Eye size={13} />}{visible ? 'Hide' : 'Show'}
                          </button>
                        )}
                        <button type="button" role="menuitem" onClick={() => { close(); deleteService(service.id, service.name); }} className="flex w-full items-center gap-2 px-3.5 py-2 text-left text-xs font-semibold text-red-500 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/20">
                          <Trash2 size={13} /> Delete
                        </button>
                      </>
                    )}
                  </RowActionsMenu>
                </td>
              </tr>;
            })}
            {!loading && !filtered.length && <tr><td colSpan={5} className="px-5 py-12 text-center text-gray-400">No services match this view.</td></tr>}
          </tbody>
        </table>
      </div>
      <div className="flex items-center justify-between gap-3 mt-3">
        <p className="text-xs text-gray-400 dark:text-gray-500">Showing {filtered.length ? start + 1 : 0} to {Math.min(start + PAGE_SIZE, filtered.length)} of {filtered.length} services</p>
        {totalPages > 1 && <div className="flex gap-2">
          <button type="button" disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)} className="px-3 py-1.5 rounded-lg text-xs border border-gray-200 dark:border-gray-800 dark:text-gray-300 disabled:opacity-40">Prev</button>
          <button type="button" disabled={currentPage === totalPages} onClick={() => setPage(currentPage + 1)} className="px-3 py-1.5 rounded-lg text-xs border border-gray-200 dark:border-gray-800 dark:text-gray-300 disabled:opacity-40">Next</button>
        </div>}
      </div>
    </div>
  );
}
