import { useState, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { 
  Search, Filter, Calendar, ChevronDown, Eye, Edit3, Trash2, Activity
} from "lucide-react";

// ─── Reusable Components ─────────────────────────────────────────────────────

const Badge = ({ status }) => {
  const styles = {
    active: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 border-green-200 dark:border-green-800",
    paused: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-200 dark:border-amber-800",
    completed: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400 border-blue-200 dark:border-blue-800",
    draft: "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400 border-gray-200 dark:border-gray-700",
    rejected: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400 border-red-200 dark:border-red-800",
  };
  return (
    <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${styles[status.toLowerCase()] || styles.draft}`}>
      {status}
    </span>
  );
};

// Mock Data (Moved outside component to avoid dependency issues)
const ADS_DATA = [
  {
    id: "AD-2024-001",
    name: "Summer Sale Campaign",
    category: "Fashion",
    status: "Active",
    totalCoins: 5000,
    coinsUsed: 2100,
    clicks: 850,
    impressions: 12500,
    startDate: "2024-03-01",
    endDate: "2024-03-15",
  },
  {
    id: "AD-2024-002",
    name: "New Product Launch",
    category: "Electronics",
    status: "Paused",
    totalCoins: 10000,
    coinsUsed: 4500,
    clicks: 1200,
    impressions: 45000,
    startDate: "2024-02-15",
    endDate: "2024-03-30",
  },
  {
    id: "AD-2024-003",
    name: "Holiday Special",
    category: "Gifts",
    status: "Completed",
    totalCoins: 2000,
    coinsUsed: 2000,
    clicks: 500,
    impressions: 8000,
    startDate: "2023-12-20",
    endDate: "2024-01-05",
  },
];

// ─── Main Component ──────────────────────────────────────────────────────────

export default function AdsManagement() {
  const navigate = useNavigate();
  const [filterStatus] = useState("All"); // Removed unused setter
  const [searchTerm, setSearchTerm] = useState("");
  const [dateRange] = useState("All Time"); // Removed unused setter

  const filteredAds = useMemo(() => {
    return ADS_DATA.filter(ad => {
      const matchStatus = filterStatus === "All" || ad.status === filterStatus;
      const matchSearch = ad.name.toLowerCase().includes(searchTerm.toLowerCase()) || ad.id.toLowerCase().includes(searchTerm.toLowerCase());
      return matchStatus && matchSearch;
    });
  }, [filterStatus, searchTerm]); // ADS_DATA is now constant, no dependency needed

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">
        
        <div className="mb-8">
          <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
              Ads Management
            </span>
          </h1>
          <p className="text-gray-500 dark:text-gray-400">Manage and track your advertising campaigns efficiently.</p>
        </div>

        {/* Filters & Actions Bar */}
        <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-4 flex-1">
            {/* Search */}
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input 
                type="text" 
                placeholder="Search by ID or Name..." 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2.5 rounded-xl text-sm bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 outline-none transition-all shadow-sm"
              />
            </div>
            
            {/* Filters */}
            <div className="flex gap-2">
              <div className="relative group">
                <button className="flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm">
                  <Filter className="w-4 h-4 text-gray-500" />
                  <span>{filterStatus}</span>
                  <ChevronDown className="w-3 h-3 text-gray-400" />
                </button>
                {/* Dropdown would go here */}
              </div>
              <div className="relative">
                <button className="flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm">
                  <Calendar className="w-4 h-4 text-gray-500" />
                  <span>{dateRange}</span>
                  <ChevronDown className="w-3 h-3 text-gray-400" />
                </button>
              </div>
            </div>
          </div>

          {/* Bulk Actions & Create */}
          <div className="flex gap-2">
            <button className="flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-medium text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors shadow-sm">
              <Trash2 className="w-4 h-4" /> Bulk Delete
            </button>
            <button className="hidden sm:flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl font-bold text-sm hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20">
              <span>+</span> Create New Ad
            </button>
          </div>
        </div>

        {/* Data Table */}
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-gray-50/50 dark:bg-gray-800/50 border-b border-gray-100 dark:border-gray-800">
                  <th className="p-4 pl-6 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Ad Name / ID</th>
                  <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Category</th>
                  <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Status</th>
                  <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider text-right">Coins</th>
                  <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider text-right">Performance</th>
                  <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Date Range</th>
                  <th className="p-4 pr-6 text-[10px] font-bold text-gray-500 uppercase tracking-wider text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                {filteredAds.map((ad) => (
                  <tr 
                    key={ad.id} 
                    onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
                    className="group hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer"
                  >
                    <td className="p-4 pl-6">
                      <div className="font-bold text-sm text-gray-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors">
                        {ad.name}
                      </div>
                      <div className="text-xs text-gray-500 font-mono mt-0.5">{ad.id}</div>
                    </td>
                    <td className="p-4 text-sm text-gray-600 dark:text-gray-300">{ad.category}</td>
                    <td className="p-4">
                      <Badge status={ad.status} />
                    </td>
                    <td className="p-4 text-right">
                      <div className="text-sm font-bold text-gray-900 dark:text-white">{ad.totalCoins.toLocaleString()}</div>
                      <div className="text-xs text-gray-400">used: {ad.coinsUsed.toLocaleString()}</div>
                    </td>
                    <td className="p-4 text-right">
                      <div className="flex flex-col items-end gap-1">
                        <span className="text-xs font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1">
                          <Eye className="w-3 h-3 text-gray-400" /> {ad.impressions.toLocaleString()}
                        </span>
                        <span className="text-xs font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1">
                          <Activity className="w-3 h-3 text-gray-400" /> {ad.clicks.toLocaleString()}
                        </span>
                      </div>
                    </td>
                    <td className="p-4 text-xs text-gray-500 dark:text-gray-400">
                      <div>{ad.startDate}</div>
                      <div className="text-[10px] text-gray-400">to {ad.endDate}</div>
                    </td>
                    <td className="p-4 pr-6 text-right">
                      <div className="flex justify-end items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity" onClick={(e) => e.stopPropagation()}>
                        <button 
                          onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
                          className="p-2 rounded-lg hover:bg-blue-50 dark:hover:bg-blue-900/20 text-blue-600 dark:text-blue-400 transition-colors" title="View"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        <button className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500 transition-colors" title="Edit">
                          <Edit3 className="w-4 h-4" />
                        </button>
                        <button className="p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 dark:text-red-400 transition-colors" title="Delete">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {filteredAds.length === 0 && (
            <div className="p-12 text-center">
              <div className="text-4xl mb-4">🔍</div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">No campaigns found</h3>
              <p className="text-gray-500 dark:text-gray-400">Try adjusting your filters or search query.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
