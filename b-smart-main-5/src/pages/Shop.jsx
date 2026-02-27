import React from 'react';
import { Search, Filter, ChevronDown } from 'lucide-react';

const Shop = () => {
  const images = [
    'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1485955900006-10f4d324d411?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1503602642458-232111445657?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1571781348782-f2c4a295579e?w=500&auto=format&fit=crop&q=60',
    'https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?w=500&auto=format&fit=crop&q=60',
  ];

  return (
    <div className="pb-16 pt-2 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row gap-6">
        {/* Filter Sidebar (Desktop) */}
        <div className="hidden md:block w-64 flex-shrink-0">
          <div className="bg-white dark:bg-black rounded-xl shadow-sm border border-gray-100 dark:border-gray-800 p-5 sticky top-24">
            <div className="flex items-center gap-2 mb-6">
              <Filter size={20} className="text-[#fa3f5e]" />
              <h2 className="font-bold text-lg dark:text-white">Filters</h2>
            </div>

            {/* Categories */}
            <div className="mb-6">
              <h3 className="font-semibold text-sm text-gray-900 dark:text-white mb-3">Categories</h3>
              <div className="space-y-2">
                {['All', 'Clothing', 'Accessories', 'Electronics', 'Home & Living'].map((cat) => (
                  <label key={cat} className="flex items-center gap-2 cursor-pointer group">
                    <input type="checkbox" className="w-4 h-4 rounded border-gray-300 text-[#fa3f5e] focus:ring-[#fa3f5e]" />
                    <span className="text-sm text-gray-600 dark:text-gray-400 group-hover:text-[#fa3f5e] transition-colors">{cat}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* Price Range */}
            <div className="mb-6">
              <h3 className="font-semibold text-sm text-gray-900 dark:text-white mb-3">Price Range</h3>
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <input type="number" placeholder="Min" className="w-20 px-2 py-1 border rounded bg-gray-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white focus:outline-none focus:border-[#fa3f5e]" />
                <span>-</span>
                <input type="number" placeholder="Max" className="w-20 px-2 py-1 border rounded bg-gray-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white focus:outline-none focus:border-[#fa3f5e]" />
              </div>
            </div>

            {/* Sort By */}
            <div>
              <h3 className="font-semibold text-sm text-gray-900 dark:text-white mb-3">Sort By</h3>
              <div className="relative">
                <select className="w-full appearance-none bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-white py-2 px-3 rounded leading-tight focus:outline-none focus:bg-white dark:focus:bg-gray-900 focus:border-[#fa3f5e] text-sm">
                  <option>Recommended</option>
                  <option>Newest</option>
                  <option>Price: Low to High</option>
                  <option>Price: High to Low</option>
                </select>
                <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700 dark:text-gray-300">
                  <ChevronDown size={14} />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="flex-1">
          <div className="px-4 md:px-0 py-2">
            <div className="bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange p-[2px] rounded-lg">
              <div className="bg-white dark:bg-gray-900 rounded-[6px] flex items-center px-3 py-2">
                <Search size={20} className="text-gray-500 dark:text-gray-400 mr-2" />
                <input type="text" placeholder="Search shops" className="bg-transparent focus:outline-none w-full dark:text-white dark:placeholder-gray-400" />
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2 md:gap-4 mt-2 px-2 md:px-0">
            {images.map((img, i) => (
              <div key={i} className="group relative aspect-square bg-gray-200 dark:bg-gray-800 rounded-lg overflow-hidden cursor-pointer">
                <img src={img} alt="Product" className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-110" />
                <div className="absolute bottom-2 left-2 bg-white/90 dark:bg-black/90 backdrop-blur-sm px-2 py-1 rounded text-xs font-bold shadow-sm dark:text-white">
                  ${(i + 1) * 15}
                </div>
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors" />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Shop;
