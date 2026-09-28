import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { Plus, Search, Pencil, Trash2, MoreVertical } from 'lucide-react';
import { CATEGORY_STYLE } from '../../data/marketplaceCategoryStyle';
import { deleteProduct } from '../../store/productsSlice';
import { Dropdown } from '../../components/productForm/ProductFormFields';

const TABS = [
  { key: 'Active',       label: 'Active' },
  { key: 'Draft',        label: 'Drafts' },
  { key: 'Out of Stock', label: 'Out of stock' },
];

const getStatus = (p) => p.status || (p.rating > 0 ? 'Active' : 'Draft');
const getStockState = (p) => {
  if (getStatus(p) === 'Out of Stock') return 'Out of stock';
  if (typeof p.stockQuantity === 'number' && p.stockQuantity <= 5) return 'Low stock';
  return 'In stock';
};

const StockCell = ({ product }) => {
  const state = getStockState(product);
  if (state === 'Low stock') return <span className="text-amber-500 font-semibold">● Low stock</span>;
  if (state === 'Out of stock') return <span className="text-red-500 font-semibold">● Out of stock</span>;
  return (
    <span className="text-gray-600 dark:text-gray-300">
      {typeof product.stockQuantity === 'number' ? `${product.stockQuantity} in stock` : '—'}
    </span>
  );
};

const VisibilityCell = ({ product }) => {
  const visible = getStatus(product) !== 'Draft';
  return (
    <span className={`flex items-center gap-1.5 font-medium ${visible ? 'text-green-600' : 'text-gray-400'}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${visible ? 'bg-green-500' : 'bg-gray-400'}`} />
      {visible ? 'Visible' : 'Hidden'}
    </span>
  );
};

const RowActionsMenu = ({ product, onDelete }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  return (
    <div className="relative inline-block" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 dark:text-gray-500 transition-colors"
        aria-label="More actions"
      >
        <MoreVertical size={16} />
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-1 w-36 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-xl z-20 overflow-hidden">
          <Link
            to={`/market/edit-product/${product.id}`}
            className="flex items-center gap-2 px-3.5 py-2.5 text-sm font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <Pencil size={13} /> Edit
          </Link>
          <button
            type="button"
            onClick={() => { setOpen(false); onDelete(product.id, product.name); }}
            className="w-full flex items-center gap-2 px-3.5 py-2.5 text-sm font-medium text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
          >
            <Trash2 size={13} /> Delete
          </button>
        </div>
      )}
    </div>
  );
};

const PAGE_SIZE = 4;

const StoreProducts = () => {
  const products = useSelector((state) => state.products.items);
  const dispatch = useDispatch();

  const [activeTab, setActiveTab] = useState('Active');
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All categories');
  const [stockFilter, setStockFilter] = useState('All stock');
  const [page, setPage] = useState(1);

  const handleDelete = (id, name) => {
    if (window.confirm(`Remove "${name}" from your store?`)) {
      dispatch(deleteProduct(id));
    }
  };

  const filteredProducts = useMemo(() => products.filter((p) => {
    if (getStatus(p) !== activeTab) return false;
    if (search.trim() && !p.name.toLowerCase().includes(search.trim().toLowerCase())) return false;
    if (categoryFilter !== 'All categories' && p.category !== categoryFilter) return false;
    if (stockFilter !== 'All stock' && getStockState(p) !== stockFilter) return false;
    return true;
  }), [products, activeTab, search, categoryFilter, stockFilter]);

  useEffect(() => { setPage(1); }, [activeTab, search, categoryFilter, stockFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredProducts.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const pageStart = (currentPage - 1) * PAGE_SIZE;
  const pagedProducts = filteredProducts.slice(pageStart, pageStart + PAGE_SIZE);

  return (
    <div className="max-w-[1280px] ml-auto px-4 md:px-8 pt-6">
      <div className="flex items-center justify-between mb-1">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">My Products</h1>
        <Link
          to="/market/add-product"
          className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange"
        >
          <Plus size={16} /> Add Product
        </Link>
      </div>
      <p className="text-xs text-gray-400 dark:text-gray-500 mb-5">
        Mock only — showing all products as a placeholder for your store, not filtered by vendor yet.
      </p>

      {/* Tabs */}
      <div className="flex gap-5 border-b border-gray-200 dark:border-gray-800 mb-4">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`pb-2.5 text-sm font-semibold border-b-2 transition-colors ${
              activeTab === tab.key
                ? 'border-[#fa3f5e] text-gray-900 dark:text-white'
                : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Search + filters */}
      <div className="flex flex-wrap gap-3 mb-4">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search products"
            className="w-full pl-9 pr-3 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] dark:text-white"
          />
        </div>
        <Dropdown
          className="w-44 flex-shrink-0"
          value={categoryFilter}
          onChange={setCategoryFilter}
          options={['All categories', ...Object.keys(CATEGORY_STYLE)]}
        />
        <Dropdown
          className="w-40 flex-shrink-0"
          value={stockFilter}
          onChange={setStockFilter}
          options={['All stock', 'In stock', 'Low stock', 'Out of stock']}
        />
      </div>

      <div className="overflow-x-auto rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-gray-400 dark:text-gray-500 border-b border-gray-100 dark:border-gray-800">
              <th className="px-5 py-3.5 font-medium">Product</th>
              <th className="px-5 py-3.5 font-medium">Price</th>
              <th className="px-5 py-3.5 font-medium">Stock</th>
              <th className="px-5 py-3.5 font-medium">Visibility</th>
              <th className="px-5 py-3.5 font-medium text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
            {pagedProducts.map((p) => {
              const style = CATEGORY_STYLE[p.category];
              const Icon = style?.icon;
              return (
                <tr key={p.id} className="hover:bg-gray-50 dark:hover:bg-gray-900/50 transition-colors">
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-3.5">
                      <div className={`w-[8rem] h-[8rem] rounded-xl flex items-center justify-center flex-shrink-0 overflow-hidden ${style?.bg}`}>
                        {p.images?.[0]
                          ? <img src={p.images[0]} alt="" className="w-full h-full object-cover" />
                          : Icon && <Icon size={24} className={`${style.text} opacity-70`} />}
                      </div>
                      <Link to={`/market/product/${p.id}`} className="font-semibold text-[15px] text-gray-900 dark:text-white hover:text-[#fa3f5e] transition-colors truncate">
                        {p.name}
                      </Link>
                    </div>
                  </td>
                  <td className="px-5 py-4 text-gray-700 dark:text-gray-300">₹{p.price.toFixed(2)}</td>
                  <td className="px-5 py-4"><StockCell product={p} /></td>
                  <td className="px-5 py-4"><VisibilityCell product={p} /></td>
                  <td className="px-5 py-4 text-right">
                    <RowActionsMenu product={p} onDelete={handleDelete} />
                  </td>
                </tr>
              );
            })}
            {filteredProducts.length === 0 && (
              <tr>
                <td colSpan={5} className="px-5 py-10 text-center text-gray-400 dark:text-gray-500">
                  No products match this view.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <div className="flex items-center justify-between mt-3">
        <p className="text-xs text-gray-400 dark:text-gray-500">
          Showing {filteredProducts.length ? pageStart + 1 : 0}–{Math.min(pageStart + PAGE_SIZE, filteredProducts.length)} of {filteredProducts.length} products
        </p>
        {totalPages > 1 && (
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={currentPage === 1}
              className="px-3 py-1.5 rounded-lg text-xs font-semibold text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-800 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              Prev
            </button>
            {Array.from({ length: totalPages }, (_, i) => i + 1).map((n) => (
              <button
                key={n}
                type="button"
                onClick={() => setPage(n)}
                className={`w-7 h-7 rounded-lg text-xs font-semibold transition-colors ${
                  n === currentPage
                    ? 'bg-[#fa3f5e] text-white'
                    : 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
                }`}
              >
                {n}
              </button>
            ))}
            <button
              type="button"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={currentPage === totalPages}
              className="px-3 py-1.5 rounded-lg text-xs font-semibold text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-800 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              Next
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default StoreProducts;
