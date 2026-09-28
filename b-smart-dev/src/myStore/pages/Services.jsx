import ServiceIcon from '../components/ServiceIcon';
import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Plus, Search, Pencil, Calendar } from 'lucide-react';
import { Dropdown } from '../../components/productForm/ProductFormFields';
import { updateService } from '../../store/servicesSlice';
import { servicePrice } from '../data/serviceFields';
import ServiceActions from '../components/ServiceActions';

const PAGE_SIZE = 7;

export default function StoreServices() {
  const services = useSelector((state) => state.services.items);
  const dispatch = useDispatch();
  const location = useLocation();
  const [tab, setTab] = useState(location.state?.serviceTab === 'Draft' ? 'Draft' : 'Published');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('All status');
  const [page, setPage] = useState(1);
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
      <div className="overflow-x-auto rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm">
        <table className="w-full text-sm">
          <thead><tr className="text-left text-gray-400 dark:text-gray-500 border-b border-gray-100 dark:border-gray-800">
            {['Service', 'Price', 'Bookings', 'Visibility', 'Actions'].map((heading) => <th key={heading} className={`px-5 py-3.5 font-medium ${heading === 'Actions' ? 'text-right' : ''}`}>{heading}</th>)}
          </tr></thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
            {filtered.slice(start, start + PAGE_SIZE).map((service) => {
              const visible = service.status === 'Published' && service.visible;
              return <tr key={service.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/30 transition-colors">
                <td className="px-5 py-4"><div className="flex items-center gap-3.5 min-w-[230px]">
                  <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-lg overflow-hidden flex-shrink-0 bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">
                    {service.images?.[0] ? <img src={service.images[0]} alt="" className="w-full h-full object-cover" /> : <ServiceIcon size={28} className="text-[#fa3f5e]" />}
                  </div>
                  <div className="min-w-0">
                    <Link to={`/market/service/${service.id}?from=services`} className="font-semibold text-gray-900 dark:text-white hover:text-[#fa3f5e]">{service.name || 'Untitled service'}</Link>
                    <p className="text-xs font-semibold text-[#fa3f5e] mt-1.5">{servicePrice(service)}</p>
                    <p className="flex items-center gap-1.5 text-xs text-gray-400 mt-1.5"><Calendar size={12} />{service.bookings} bookings</p>
                  </div>
                </div></td>
                <td className="px-5 py-4 text-gray-600 dark:text-gray-300 whitespace-nowrap">{servicePrice(service)}</td>
                <td className="px-5 py-4 text-gray-500 dark:text-gray-400">{service.bookings}</td>
                <td className="px-5 py-4"><button type="button" disabled={service.status === 'Draft'} aria-label={`${visible ? 'Hide' : 'Show'} ${service.name}`} onClick={() => dispatch(updateService({ id: service.id, visible: !service.visible }))} className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium ${visible ? 'bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400' : 'bg-gray-100 text-gray-500 dark:bg-gray-800'}`}><span className={`w-1.5 h-1.5 rounded-full ${visible ? 'bg-green-500' : 'bg-gray-400'}`} />{visible ? 'Visible' : 'Hidden'}</button></td>
                <td className="px-5 py-4"><div className="flex items-center justify-end gap-3 whitespace-nowrap">
                  <Link to={`/market/service/${service.id}?from=services`} aria-label={`View ${service.name}`} className="inline-flex items-center rounded-lg px-3 py-2 text-xs font-semibold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">View service</Link>
                  <Link to={`/market/edit-service/${service.id}`} aria-label={`Edit ${service.name}`} className="inline-flex items-center gap-1.5 text-xs font-semibold text-gray-600 dark:text-gray-300 hover:text-[#fa3f5e]"><Pencil size={13} /> Edit</Link>
                  <ServiceActions service={service} />
                </div></td>
              </tr>;
            })}
            {!filtered.length && <tr><td colSpan={5} className="px-5 py-12 text-center text-gray-400">No services match this view.</td></tr>}
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
