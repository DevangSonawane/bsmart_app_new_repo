import { useState, useMemo, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useSelector } from "react-redux";
import api from "../../lib/api";
import { 
  Search, Filter, Calendar, ChevronDown, Eye, Edit3, Trash2, Activity,
  ChevronLeft, ChevronRight
} from "lucide-react";

// ─── Reusable Components ─────────────────────────────────────────────────────

const Badge = ({ status }) => {
  const styles = {
    active: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 border-green-200 dark:border-green-800",
    paused: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-200 dark:border-amber-800",
    completed: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400 border-blue-200 dark:border-blue-800",
    draft: "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400 border-gray-200 dark:border-gray-700",
    rejected: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400 border-red-200 dark:border-red-800",
    pending: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400 border-yellow-200 dark:border-yellow-800",
  };
  return (
    <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${styles[(status || "").toLowerCase()] || styles.draft}`}>
      {status || "Unknown"}
    </span>
  );
};

// ─── Main Component ──────────────────────────────────────────────────────────

export default function AdsManagement() {
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;

  const [ads, setAds] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState("All");
  
  const [filterStatus] = useState("All");
  const [searchTerm, setSearchTerm] = useState("");

  // Fetch Categories
  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const res = await api.get("/ads/categories");
        if (res.data && res.data.categories) {
          const uniqueCats = res.data.categories.filter(c => c !== "All");
          setCategories(["All", ...uniqueCats]);
        }
      } catch (err) {
        console.error("Failed to fetch categories", err);
        setCategories(["All", "Accessories", "Electronics", "Fashion", "Food", "Travel"]);
      }
    };
    fetchCategories();
  }, []);

  // Fetch User Ads
  useEffect(() => {
    const fetchAds = async () => {
      if (!userId) return;
      setLoading(true);
      setError("");
      try {
        let url = `/ads/user/${userId}`;
        const params = new URLSearchParams();
        if (selectedCategory !== "All") params.append("category", selectedCategory);
        
        const queryString = params.toString();
        if (queryString) url += `?${queryString}`;

        const res = await api.get(url);

        // Handle both array and paginated object response
        const adsData = Array.isArray(res.data)
          ? res.data
          : Array.isArray(res.data?.ads)
          ? res.data.ads
          : Array.isArray(res.data?.data)
          ? res.data.data
          : [];

        // Normalize to match actual API response shape
        const normalizedAds = adsData.map(ad => ({
          id: ad._id || ad.id,
          // Use caption as the ad "name" since there's no title field
          name: ad.caption || ad.title || "Untitled Ad",
          category: ad.category || "Uncategorized",
          status: ad.status || "draft",
          // username from nested user_id object
          username: ad.user_id?.username || ad.user_id?.full_name || "—",
          // business name from nested vendor_id object
          businessName: ad.vendor_id?.business_name || "—",
          totalCoins: ad.total_budget_coins || ad.budget || 0,
          coinsUsed: ad.total_coins_spent || ad.spend || 0,
          views: ad.views_count || 0,
          uniqueViews: ad.unique_views_count || 0,
          completedViews: ad.completed_views_count || 0,
          likes: ad.likes_count || 0,
          comments: ad.comments_count || 0,
          contentType: ad.content_type || "—",
          location: ad.location || "—",
          createdAt: ad.createdAt ? new Date(ad.createdAt).toLocaleDateString() : "-",
        }));

        setAds(normalizedAds);
      } catch (err) {
        console.error("Failed to fetch ads", err);
        setError("Failed to load campaigns.");
      } finally {
        setLoading(false);
      }
    };

    fetchAds();
  }, [userId, selectedCategory]);

  const filteredAds = useMemo(() => {
    return ads.filter(ad => {
      const matchStatus = filterStatus === "All" || ad.status.toLowerCase() === filterStatus.toLowerCase();
      const matchSearch =
        ad.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        ad.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
        ad.username.toLowerCase().includes(searchTerm.toLowerCase());
      return matchStatus && matchSearch;
    });
  }, [ads, filterStatus, searchTerm]);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-4 md:p-8">
        
        <div className="mb-6 md:mb-8">
          <h1 className="text-2xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
              Ads Management
            </span>
          </h1>
          <p className="text-sm md:text-base text-gray-500 dark:text-gray-400">Manage and track your advertising campaigns efficiently.</p>
        </div>

        {/* Category Tabs */}
        <div className="mb-6 -mx-4 px-4 md:mx-0 md:px-0 overflow-x-auto scrollbar-hide">
          <div className="flex gap-2 min-w-max pb-2">
            {categories.map(cat => (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`px-4 py-2 rounded-full text-sm font-semibold transition-all whitespace-nowrap
                  ${selectedCategory === cat 
                    ? "bg-gray-900 dark:bg-white text-white dark:text-black shadow-lg" 
                    : "bg-white dark:bg-gray-900 text-gray-600 dark:text-gray-400 border border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800"}
                `}
              >
                {cat}
              </button>
            ))}
          </div>
        </div>

        {/* Search Bar */}
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3 flex-1">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by caption, username, or ID..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-4 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 outline-none transition-all"
              />
            </div>
          </div>
          <button
            onClick={() => navigate("/vendor/ads-management/create")}
            className="flex-1 sm:flex-none flex justify-center items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl font-bold text-sm hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20 whitespace-nowrap"
          >
            <span>+</span> Create Ad
          </button>
        </div>

        {/* Loading State */}
        {loading && (
          <div className="py-20 text-center">
            <div className="w-10 h-10 border-4 border-pink-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-gray-500">Loading campaigns...</p>
          </div>
        )}

        {/* Error State */}
        {error && (
          <div className="p-6 text-center bg-red-50 dark:bg-red-900/10 rounded-2xl border border-red-100 dark:border-red-900/30 text-red-600 dark:text-red-400 mb-6">
            <p>{error}</p>
            <button onClick={() => window.location.reload()} className="mt-2 text-sm font-bold underline">Try Again</button>
          </div>
        )}

        {/* Table */}
        {!loading && !error && (
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl overflow-hidden shadow-sm">
            
            {/* Desktop Table */}
            <div className="hidden md:block overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-gray-50/50 dark:bg-gray-800/50 border-b border-gray-100 dark:border-gray-800">
                    <th className="p-4 pl-6 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Post ID</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Caption</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Category</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Username</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Status</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider text-right">Budget</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Created</th>
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
                      {/* Post ID */}
                      <td className="p-4 pl-6">
                        <div className="text-xs text-gray-500 font-mono bg-gray-100 dark:bg-gray-800 px-2 py-1 rounded w-fit max-w-[110px] truncate" title={ad.id}>
                          {ad.id}
                        </div>
                      </td>

                      {/* Caption */}
                      <td className="p-4">
                        <div className="font-semibold text-sm text-gray-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors max-w-[180px] truncate" title={ad.name}>
                          {ad.name}
                        </div>
                        <div className="text-xs text-gray-400 mt-0.5 capitalize">{ad.contentType}</div>
                      </td>

                      {/* Category */}
                      <td className="p-4 text-sm text-gray-600 dark:text-gray-300">{ad.category}</td>

                      {/* Username */}
                      <td className="p-4">
                        <div className="text-sm font-semibold text-gray-900 dark:text-white">@{ad.username}</div>
                        <div className="text-xs text-gray-400 truncate max-w-[120px]">{ad.businessName}</div>
                      </td>

                      {/* Status */}
                      <td className="p-4">
                        <Badge status={ad.status} />
                      </td>

                      {/* Budget */}
                      <td className="p-4 text-right">
                        <div className="text-sm font-bold text-gray-900 dark:text-white">{ad.totalCoins.toLocaleString()} <span className="text-xs font-normal text-gray-400">coins</span></div>
                        <div className="text-xs text-gray-400">spent: {ad.coinsUsed.toLocaleString()}</div>
                      </td>

                      {/* Created */}
                      <td className="p-4 text-xs text-gray-500 dark:text-gray-400">{ad.createdAt}</td>

                      {/* Actions */}
                      <td className="p-4 pr-6 text-right">
                        <div className="flex justify-end items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity" onClick={(e) => e.stopPropagation()}>
                          <button
                            onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
                            className="p-2 rounded-lg hover:bg-blue-50 dark:hover:bg-blue-900/20 text-blue-600 dark:text-blue-400 transition-colors"
                            title="View"
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

            {/* Mobile Card View */}
            <div className="md:hidden divide-y divide-gray-100 dark:divide-gray-800">
              {filteredAds.map((ad) => (
                <div
                  key={ad.id}
                  onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
                  className="p-4 active:bg-gray-50 dark:active:bg-gray-800 transition-colors"
                >
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <div className="font-bold text-gray-900 dark:text-white mb-1 truncate max-w-[200px]">{ad.name}</div>
                      <div className="flex items-center gap-2 text-xs text-gray-500">
                        <span className="font-mono bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded">{ad.id.slice(0, 10)}...</span>
                        <span>•</span>
                        <span>{ad.category}</span>
                      </div>
                    </div>
                    <Badge status={ad.status} />
                  </div>

                  <div className="flex items-center gap-2 mb-3 text-xs text-gray-500">
                    <span>@{ad.username}</span>
                    <span>•</span>
                    <span>{ad.businessName}</span>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-3 mb-4">
                    <div className="bg-gray-50 dark:bg-gray-800/50 p-3 rounded-xl">
                      <div className="text-[10px] text-gray-400 uppercase font-bold mb-1">Budget</div>
                      <div className="text-sm font-bold text-gray-900 dark:text-white">{ad.totalCoins.toLocaleString()} coins</div>
                      <div className="text-[10px] text-gray-500">spent: {ad.coinsUsed.toLocaleString()}</div>
                    </div>
                    <div className="bg-gray-50 dark:bg-gray-800/50 p-3 rounded-xl">
                      <div className="text-[10px] text-gray-400 uppercase font-bold mb-1">Views</div>
                      <div className="text-sm font-bold text-gray-900 dark:text-white">{ad.views.toLocaleString()}</div>
                      <div className="text-[10px] text-gray-500">unique: {ad.uniqueViews.toLocaleString()}</div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-gray-800">
                    <div className="text-xs text-gray-400">{ad.createdAt}</div>
                    <div className="flex gap-1">
                      <button className="p-2 text-gray-400 hover:text-blue-500"><Edit3 className="w-4 h-4" /></button>
                      <button className="p-2 text-gray-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {filteredAds.length === 0 && (
              <div className="p-12 text-center">
                <div className="text-4xl mb-4">🔍</div>
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">No campaigns found</h3>
                <p className="text-gray-500 dark:text-gray-400 mt-1">Try adjusting your filters or search query.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}