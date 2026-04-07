import { useState, useMemo, useEffect } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import { useSelector } from "react-redux";
import api from "../../lib/api";
import EditContentModal from "../../components/EditContentModal";
import {
  Search, Eye, Edit3, Trash2, Pause, Play, Send,
  Plus, Target, MousePointerClick, Megaphone, Tag,
  ChevronDown, X
} from "lucide-react";

// ─── Reusable Components ──────────────────────────────────────────────────────

const Badge = ({ status }) => {
  const styles = {
    active:    "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 border-green-200 dark:border-green-800",
    paused:    "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-200 dark:border-amber-800",
    completed: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400 border-blue-200 dark:border-blue-800",
    draft:     "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400 border-gray-200 dark:border-gray-700",
    rejected:  "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400 border-red-200 dark:border-red-800",
    pending:   "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400 border-yellow-200 dark:border-yellow-800",
  };
  return (
    <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${styles[(status || "").toLowerCase()] || styles.draft}`}>
      {status || "Unknown"}
    </span>
  );
};

const AdTypeBadge = ({ type }) => {
  const map = {
    banner:         { label: "Banner",         cls: "bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400 border-blue-100 dark:border-blue-900" },
    video:          { label: "Video",          cls: "bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400 border-purple-100 dark:border-purple-900" },
    carousel:       { label: "Carousel",       cls: "bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400 border-orange-100 dark:border-orange-900" },
    sponsored_post: { label: "Sponsored",      cls: "bg-pink-50 text-pink-600 dark:bg-pink-900/20 dark:text-pink-400 border-pink-100 dark:border-pink-900" },
  };
  const cfg = map[(type || "").toLowerCase()] || { label: type || "—", cls: "bg-gray-50 text-gray-500 border-gray-100" };
  return (
    <span className={`px-2 py-0.5 rounded-md text-[10px] font-bold border ${cfg.cls}`}>
      {cfg.label}
    </span>
  );
};

const CtaBadge = ({ type }) => {
  const labels = {
    view_site:    "View Site",
    contact_info: "Contact",
    install_app:  "Install",
    book_now:     "Book Now",
    learn_more:   "Learn More",
    call_now:     "Call Now",
  };
  if (!type) return <span className="text-gray-400 text-xs">—</span>;
  return (
    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-indigo-50 dark:bg-indigo-900/20 text-indigo-600 dark:text-indigo-400 text-[10px] font-bold border border-indigo-100 dark:border-indigo-900">
      <MousePointerClick className="w-2.5 h-2.5" />
      {labels[type] || type}
    </span>
  );
};

// ─── Main Component ──────────────────────────────────────────────────────────

export default function AdsManagement() {
  const navigate = useNavigate();
  const { handleOpenCreateModal } = useOutletContext() || {};

  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;

  const [profileCompletion, setProfileCompletion] = useState(0);
  const [vendorValidated, setVendorValidated] = useState(false);
  const [activePackageAdsLimit, setActivePackageAdsLimit] = useState(0);
  const [showInactivePopup, setShowInactivePopup] = useState(false);
  const [showProfileGatePopup, setShowProfileGatePopup] = useState(false);
  const [showAdLimitPopup, setShowAdLimitPopup] = useState(false);
  const [editingAd, setEditingAd] = useState(null);
  const [actionKey, setActionKey] = useState("");

  const [ads, setAds] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [filterStatus, setFilterStatus] = useState("All");
  const [filterAdType, setFilterAdType] = useState("All");
  const [searchTerm, setSearchTerm] = useState("");
  const [showFilters, setShowFilters] = useState(false);

  const normalizeAd = (ad) => ({
    id: ad._id || ad.id,
    _id: ad._id || ad.id,
    // core
    name: ad.ad_title || ad.caption || ad.title || "Untitled Ad",
    ad_title: ad.ad_title || "",
    ad_description: ad.ad_description || "",
    caption: ad.caption || ad.title || "",
    ad_type: ad.ad_type || "sponsored_post",
    // cta
    cta: ad.cta || {},
    // targeting
    targeting: ad.targeting || {},
    // categorization
    category: ad.category || "Uncategorized",
    sub_category: ad.sub_category || "",
    keywords: ad.keywords || [],
    tags: ad.tags || [],
    // status
    status: ad.status || "draft",
    // compliance
    compliance: ad.compliance || {},
    // budget
    totalCoins: ad.total_budget_coins || 0,
    total_budget_coins: ad.total_budget_coins || 0,
    coinsUsed: ad.total_coins_spent || 0,
    budget: ad.budget || {},
    // stats
    views: ad.views_count || 0,
    uniqueViews: ad.unique_views_count || 0,
    completedViews: ad.completed_views_count || 0,
    likes: ad.likes_count || 0,
    comments: ad.comments_count || 0,
    // user
    username: ad.user_id?.username || ad.user_id?.full_name || "—",
    businessName: ad.vendor_id?.business_name || "—",
    // meta
    contentType: ad.content_type || "—",
    content_type: ad.content_type || "reel",
    location: ad.location || "—",
    createdAt: ad.createdAt ? new Date(ad.createdAt).toLocaleDateString() : "-",
    // arrays
    media: ad.media || [],
    hashtags: ad.hashtags || [],
    target_language: ad.target_language || [],
    target_location: ad.target_location || [],
    target_states: ad.target_states || [],
    tagged_users: ad.tagged_users || [],
    engagement_controls: ad.engagement_controls || {},
    scheduling: ad.scheduling || {},
    ab_testing: ad.ab_testing || {},
    tracking: ad.tracking || {},
    user_id: ad.user_id,
    vendor_id: ad.vendor_id,
  });

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const res = await api.get("/ads/categories");
        if (res.data?.categories) {
          const uniqueCats = res.data.categories.filter(c => c !== "All");
          setCategories(["All", ...uniqueCats]);
        }
      } catch {
        setCategories(["All", "Accessories", "Electronics", "Fashion", "Food", "Travel"]);
      }
    };
    fetchCategories();
  }, []);

  useEffect(() => {
    const fetchAds = async () => {
      if (!userId) return;
      setLoading(true); setError("");
      try {
        let url = `/ads/user/${userId}`;
        const params = new URLSearchParams();
        if (selectedCategory !== "All") params.append("category", selectedCategory);
        const qs = params.toString();
        if (qs) url += `?${qs}`;
        const res = await api.get(url);
        const adsData = Array.isArray(res.data)
          ? res.data
          : Array.isArray(res.data?.ads) ? res.data.ads
          : Array.isArray(res.data?.data) ? res.data.data : [];
        setAds(adsData.map(normalizeAd));
      } catch {
        setError("Failed to load campaigns.");
      } finally { setLoading(false); }
    };
    fetchAds();
  }, [userId, selectedCategory]);

  useEffect(() => {
    const fetchVendorProfile = async () => {
      if (!userId) return;
      try {
        const [profileRes, packageRes] = await Promise.all([
          api.get(`/vendors/profile/${userId}`),
          api.get("/vendor-packages/my/active").catch(() => ({ data: null })),
        ]);
        setProfileCompletion(Number(profileRes.data?.profile_completion_percentage || 0));
        setVendorValidated(Boolean(profileRes.data?.validated));
        const activePackage = packageRes?.data?.active_package || packageRes?.data?.package || packageRes?.data || null;
        const packageData = activePackage?.package || activePackage || {};
        setActivePackageAdsLimit(Number(packageData?.ads_allowed_max || 0));
      } catch {
        setProfileCompletion(0); setVendorValidated(false); setActivePackageAdsLimit(0);
      }
    };
    fetchVendorProfile();
  }, [userId]);

  const activeFiltersCount = [
    filterStatus !== "All",
    filterAdType !== "All",
  ].filter(Boolean).length;

  const filteredAds = useMemo(() => {
    return ads.filter(ad => {
      const matchStatus  = filterStatus === "All"  || ad.status.toLowerCase()  === filterStatus.toLowerCase();
      const matchAdType  = filterAdType === "All"  || ad.ad_type.toLowerCase() === filterAdType.toLowerCase();
      const matchSearch  =
        (ad.name || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (ad.ad_title || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (ad.id || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (ad.username || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (ad.sub_category || "").toLowerCase().includes(searchTerm.toLowerCase());
      return matchStatus && matchAdType && matchSearch;
    });
  }, [ads, filterStatus, filterAdType, searchTerm]);

  const handleCreateAd = () => {
    if (!vendorValidated) { setShowInactivePopup(true); return; }
    if (Number(profileCompletion || 0) <= 80) { setShowProfileGatePopup(true); return; }
    if (Number(activePackageAdsLimit || 0) <= 0 || ads.length >= Number(activePackageAdsLimit || 0)) {
      setShowAdLimitPopup(true); return;
    }
    if (handleOpenCreateModal) handleOpenCreateModal("ad");
    else navigate("/vendor/ads-management/create");
  };

  const handleAdUpdated = (updatedData) => {
    const updatedAd = normalizeAd(updatedData?.ad || updatedData?.data || updatedData || {});
    if (!updatedAd?.id) { setEditingAd(null); return; }
    setAds((prev) => prev.map((ad) => (ad.id === updatedAd.id ? { ...ad, ...updatedAd } : ad)));
    setEditingAd(null);
  };

  const handleAdStatusChange = async (adId, nextStatus) => {
    const key = `${adId}:${nextStatus}`;
    try {
      setActionKey(key); setError("");
      const { data } = await api.patch(`/ads/${adId}/metadata`, { status: nextStatus });
      const updatedAd = normalizeAd(data?.ad || data?.data || data || {});
      setAds((prev) => prev.map((ad) => (ad.id === updatedAd.id ? { ...ad, ...updatedAd } : ad)));
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to update ad status.");
    } finally { setActionKey(""); }
  };

  const handleDeleteAd = async (adId) => {
    if (!window.confirm("Delete this ad?")) return;
    const key = `${adId}:delete`;
    try {
      setActionKey(key); setError("");
      await api.delete(`/ads/${adId}`);
      setAds((prev) => prev.filter((ad) => ad.id !== adId));
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to delete ad.");
    } finally { setActionKey(""); }
  };

  const handleEditAd = async (adId) => {
    try {
      const { data } = await api.get(`/ads/${adId}`);
      setEditingAd(normalizeAd(data?.ad || data?.data || data || {}));
    } catch { /* silent */ }
  };

  const renderAdActions = (ad, compact = false) => {
    const isBusy = (suffix) => actionKey === `${ad.id}:${suffix}`;
    const btn = compact ? "p-2 text-gray-400 transition-colors" : "p-2 rounded-lg transition-colors";
    return (
      <>
        <button onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
          className={`${btn} hover:bg-blue-50 dark:hover:bg-blue-900/20 text-blue-600 dark:text-blue-400`} title="View">
          <Eye className="w-4 h-4" />
        </button>
        <button onClick={() => handleEditAd(ad.id)}
          className={`${btn} hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500`} title="Edit">
          <Edit3 className="w-4 h-4" />
        </button>
        {ad.status === "draft" && (
          <button onClick={() => handleAdStatusChange(ad.id, "pending")}
            className={`${btn} hover:bg-emerald-50 dark:hover:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400 disabled:opacity-50`}
            title="Submit" disabled={isBusy("pending")}>
            <Send className="w-4 h-4" />
          </button>
        )}
        {ad.status === "active" && (
          <button onClick={() => handleAdStatusChange(ad.id, "paused")}
            className={`${btn} hover:bg-amber-50 dark:hover:bg-amber-900/20 text-amber-600 dark:text-amber-400 disabled:opacity-50`}
            title="Pause" disabled={isBusy("paused")}>
            <Pause className="w-4 h-4" />
          </button>
        )}
        {ad.status === "paused" && (
          <button onClick={() => handleAdStatusChange(ad.id, "active")}
            className={`${btn} hover:bg-emerald-50 dark:hover:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400 disabled:opacity-50`}
            title="Resume" disabled={isBusy("active")}>
            <Play className="w-4 h-4" />
          </button>
        )}
        <button onClick={() => handleDeleteAd(ad.id)}
          className={`${btn} hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 dark:text-red-400 disabled:opacity-50`}
          title="Delete" disabled={isBusy("delete")}>
          <Trash2 className="w-4 h-4" />
        </button>
      </>
    );
  };

  // ── Summary stat pills at top ─────────────────────────────────────────────
  const summaryStats = useMemo(() => {
    const total   = ads.length;
    const active  = ads.filter(a => a.status === "active").length;
    const pending = ads.filter(a => a.status === "pending").length;
    const draft   = ads.filter(a => a.status === "draft").length;
    const totalBudget = ads.reduce((s, a) => s + a.totalCoins, 0);
    const totalSpent  = ads.reduce((s, a) => s + a.coinsUsed, 0);
    return { total, active, pending, draft, totalBudget, totalSpent };
  }, [ads]);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-4 md:p-8">

        {/* ── Header ── */}
        <div className="mb-6 md:mb-8 flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-4xl font-extrabold tracking-tight mb-1">
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
                Ads Management
              </span>
            </h1>
            <p className="text-sm text-gray-500 dark:text-gray-400">Manage and track your advertising campaigns.</p>
          </div>
          <button
            onClick={handleCreateAd}
            className="self-start sm:self-auto flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl font-bold text-sm hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20 whitespace-nowrap"
          >
            <Plus className="w-4 h-4" /> Create Ad
          </button>
        </div>

        {/* ── Summary Stats ── */}
        {!loading && ads.length > 0 && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
            {[
              { label: "Total Ads",     value: summaryStats.total,                       color: "text-gray-900 dark:text-white",     bg: "bg-white dark:bg-gray-900" },
              { label: "Active",        value: summaryStats.active,                      color: "text-green-600 dark:text-green-400",bg: "bg-white dark:bg-gray-900" },
              { label: "Total Budget",  value: `${summaryStats.totalBudget.toLocaleString()} 🪙`, color: "text-amber-600 dark:text-amber-400", bg: "bg-white dark:bg-gray-900" },
              { label: "Total Spent",   value: `${summaryStats.totalSpent.toLocaleString()} 🪙`,  color: "text-red-500 dark:text-red-400",    bg: "bg-white dark:bg-gray-900" },
            ].map((s, i) => (
              <div key={i} className={`${s.bg} border border-gray-100 dark:border-gray-800 rounded-2xl p-4 shadow-sm`}>
                <div className="text-[10px] text-gray-400 uppercase tracking-wider font-bold mb-1">{s.label}</div>
                <div className={`text-lg font-extrabold ${s.color}`}>{s.value}</div>
              </div>
            ))}
          </div>
        )}

        {/* ── Category Tabs ── */}
        <div className="mb-5 -mx-4 px-4 md:mx-0 md:px-0 overflow-x-auto scrollbar-hide">
          <div className="flex gap-2 min-w-max pb-2">
            {categories.map(cat => (
              <button key={cat} onClick={() => setSelectedCategory(cat)}
                className={`px-4 py-2 rounded-full text-sm font-semibold transition-all whitespace-nowrap
                  ${selectedCategory === cat
                    ? "bg-gray-900 dark:bg-white text-white dark:text-black shadow-lg"
                    : "bg-white dark:bg-gray-900 text-gray-600 dark:text-gray-400 border border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800"}`}
              >
                {cat}
              </button>
            ))}
          </div>
        </div>

        {/* ── Search + Filters ── */}
        <div className="flex flex-col sm:flex-row gap-3 mb-6">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by title, caption, username, sub-category or ID..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl text-sm focus:ring-2 focus:ring-pink-500 outline-none transition-all"
            />
          </div>

          <button
            onClick={() => setShowFilters(v => !v)}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold border transition-all
              ${showFilters || activeFiltersCount > 0
                ? "bg-pink-50 dark:bg-pink-900/20 border-pink-200 dark:border-pink-800 text-pink-600 dark:text-pink-400"
                : "bg-white dark:bg-gray-900 border-gray-200 dark:border-gray-800 text-gray-600 dark:text-gray-400"}`}
          >
            <Target className="w-4 h-4" />
            Filters
            {activeFiltersCount > 0 && (
              <span className="w-5 h-5 rounded-full bg-pink-600 text-white text-[10px] font-bold flex items-center justify-center">{activeFiltersCount}</span>
            )}
            <ChevronDown className={`w-3.5 h-3.5 transition-transform ${showFilters ? "rotate-180" : ""}`} />
          </button>
        </div>

        {/* ── Filter Panel ── */}
        {showFilters && (
          <div className="mb-6 p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm">
            <div className="flex flex-wrap gap-6">
              {/* Status filter */}
              <div>
                <div className="text-[10px] text-gray-400 uppercase tracking-wider font-bold mb-2">Status</div>
                <div className="flex flex-wrap gap-2">
                  {["All", "active", "pending", "paused", "draft", "rejected"].map(s => (
                    <button key={s} onClick={() => setFilterStatus(s)}
                      className={`px-3 py-1.5 rounded-full text-xs font-bold border transition-all capitalize
                        ${filterStatus === s
                          ? "bg-gray-900 dark:bg-white text-white dark:text-black border-transparent"
                          : "bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700 hover:border-gray-300"}`}
                    >{s}</button>
                  ))}
                </div>
              </div>

              {/* Ad Type filter */}
              <div>
                <div className="text-[10px] text-gray-400 uppercase tracking-wider font-bold mb-2">Ad Type</div>
                <div className="flex flex-wrap gap-2">
                  {["All", "banner", "video", "carousel", "sponsored_post"].map(t => (
                    <button key={t} onClick={() => setFilterAdType(t)}
                      className={`px-3 py-1.5 rounded-full text-xs font-bold border transition-all capitalize
                        ${filterAdType === t
                          ? "bg-gray-900 dark:bg-white text-white dark:text-black border-transparent"
                          : "bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700 hover:border-gray-300"}`}
                    >{t.replace("_", " ")}</button>
                  ))}
                </div>
              </div>

              {activeFiltersCount > 0 && (
                <div className="flex items-end">
                  <button onClick={() => { setFilterStatus("All"); setFilterAdType("All"); }}
                    className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors">
                    <X className="w-3 h-3" /> Clear all
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ── Loading ── */}
        {loading && (
          <div className="py-20 text-center">
            <div className="w-10 h-10 border-4 border-pink-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-gray-500">Loading campaigns...</p>
          </div>
        )}

        {/* ── Error ── */}
        {error && (
          <div className="p-6 text-center bg-red-50 dark:bg-red-900/10 rounded-2xl border border-red-100 dark:border-red-900/30 text-red-600 dark:text-red-400 mb-6">
            <p>{error}</p>
            <button onClick={() => window.location.reload()} className="mt-2 text-sm font-bold underline">Try Again</button>
          </div>
        )}

        {/* ── Table ── */}
        {!loading && !error && (
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl overflow-hidden shadow-sm">

            {/* Desktop Table */}
            <div className="hidden lg:block overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-gray-50/50 dark:bg-gray-800/50 border-b border-gray-100 dark:border-gray-800">
                    <th className="p-4 pl-6 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Ad</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Type / CTA</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Category</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Targeting</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Status</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider text-right">Budget</th>
                    <th className="p-4 text-[10px] font-bold text-gray-500 uppercase tracking-wider">Created</th>
                    <th className="p-4 pr-6 text-[10px] font-bold text-gray-500 uppercase tracking-wider text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                  {filteredAds.map((ad) => {
                    const targeting = ad.targeting || {};
                    const hasTargeting = (targeting.countries?.length || 0) + (targeting.cities?.length || 0) + (targeting.age_min ? 1 : 0) > 0;
                    const targetingSummary = hasTargeting
                      ? [
                          targeting.countries?.length ? `${targeting.countries[0]}${targeting.countries.length > 1 ? ` +${targeting.countries.length - 1}` : ""}` : null,
                          targeting.age_min || targeting.age_max ? `${targeting.age_min || 13}–${targeting.age_max || 65}y` : null,
                          targeting.gender && targeting.gender !== "all" ? targeting.gender : null,
                        ].filter(Boolean).join(" · ")
                      : (ad.target_location?.length ? ad.target_location[0] : null);

                    return (
                      <tr key={ad.id}
                        onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
                        className="group hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer">

                        {/* Ad title + caption */}
                        <td className="p-4 pl-6">
                          <div className="font-semibold text-sm text-gray-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors max-w-[200px] truncate" title={ad.ad_title || ad.name}>
                            {ad.ad_title || ad.name}
                          </div>
                          {ad.caption && ad.caption !== ad.ad_title && (
                            <div className="text-xs text-gray-400 mt-0.5 max-w-[200px] truncate">{ad.caption}</div>
                          )}
                          <div className="text-[10px] font-mono text-gray-300 dark:text-gray-700 mt-0.5">@{ad.username}</div>
                        </td>

                        {/* Ad type + CTA */}
                        <td className="p-4">
                          <div className="flex flex-col gap-1.5">
                            <AdTypeBadge type={ad.ad_type} />
                            <CtaBadge type={ad.cta?.type} />
                          </div>
                        </td>

                        {/* Category + sub-category */}
                        <td className="p-4">
                          <div className="flex items-center gap-1.5">
                            <Tag className="w-3 h-3 text-gray-400 flex-shrink-0" />
                            <span className="text-sm text-gray-700 dark:text-gray-300 font-medium">{ad.category}</span>
                          </div>
                          {ad.sub_category && (
                            <div className="text-xs text-gray-400 mt-0.5 pl-4 truncate max-w-[120px]">{ad.sub_category}</div>
                          )}
                        </td>

                        {/* Targeting summary */}
                        <td className="p-4">
                          {targetingSummary ? (
                            <div className="flex items-start gap-1">
                              <Target className="w-3 h-3 text-indigo-400 flex-shrink-0 mt-0.5" />
                              <span className="text-xs text-gray-600 dark:text-gray-400 leading-snug">{targetingSummary}</span>
                            </div>
                          ) : (
                            <span className="text-xs text-gray-300 dark:text-gray-700 italic">All audiences</span>
                          )}
                          {ad.targeting?.device_types?.length > 0 && (
                            <div className="text-[10px] text-gray-400 mt-0.5 pl-4">{ad.targeting.device_types.join(", ")}</div>
                          )}
                        </td>

                        {/* Status + compliance */}
                        <td className="p-4">
                          <div className="flex flex-col gap-1">
                            <Badge status={ad.status} />
                            {ad.compliance?.approval_status && ad.compliance.approval_status !== ad.status && (
                              <span className="text-[9px] text-gray-400 font-semibold uppercase tracking-wider">
                                Review: {ad.compliance.approval_status}
                              </span>
                            )}
                          </div>
                        </td>

                        {/* Budget */}
                        <td className="p-4 text-right">
                          <div className="text-sm font-bold text-gray-900 dark:text-white">{ad.totalCoins.toLocaleString()} <span className="text-xs font-normal text-gray-400">🪙</span></div>
                          <div className="text-xs text-gray-400">spent: {ad.coinsUsed.toLocaleString()}</div>
                          {ad.budget?.daily_budget_coins > 0 && (
                            <div className="text-[10px] text-indigo-400 mt-0.5">{ad.budget.daily_budget_coins.toLocaleString()}/day</div>
                          )}
                        </td>

                        {/* Date */}
                        <td className="p-4 text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">
                          {ad.createdAt}
                          {ad.budget?.start_date && (
                            <div className="text-[10px] text-gray-400 mt-0.5">
                              Starts: {new Date(ad.budget.start_date).toLocaleDateString()}
                            </div>
                          )}
                        </td>

                        {/* Actions */}
                        <td className="p-4 pr-6 text-right">
                          <div className="flex justify-end items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity" onClick={(e) => e.stopPropagation()}>
                            {renderAdActions(ad)}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Mobile Card View */}
            <div className="lg:hidden divide-y divide-gray-100 dark:divide-gray-800">
              {filteredAds.map((ad) => (
                <div key={ad.id}
                  onClick={() => navigate(`/vendor/ads-management/${ad.id}`)}
                  className="p-4 active:bg-gray-50 dark:active:bg-gray-800 transition-colors">

                  <div className="flex justify-between items-start mb-3">
                    <div className="min-w-0 flex-1 pr-3">
                      <div className="font-bold text-gray-900 dark:text-white mb-0.5 truncate">{ad.ad_title || ad.name}</div>
                      {ad.caption && ad.caption !== ad.ad_title && (
                        <div className="text-xs text-gray-400 truncate">{ad.caption}</div>
                      )}
                      <div className="flex items-center gap-2 mt-1 flex-wrap">
                        <AdTypeBadge type={ad.ad_type} />
                        <CtaBadge type={ad.cta?.type} />
                      </div>
                    </div>
                    <Badge status={ad.status} />
                  </div>

                  <div className="flex items-center gap-2 mb-3 text-xs text-gray-500">
                    <Tag className="w-3 h-3" />
                    <span>{ad.category}{ad.sub_category ? ` › ${ad.sub_category}` : ""}</span>
                    <span>•</span>
                    <span>@{ad.username}</span>
                  </div>

                  <div className="grid grid-cols-2 gap-3 mb-4">
                    <div className="bg-gray-50 dark:bg-gray-800/50 p-3 rounded-xl">
                      <div className="text-[10px] text-gray-400 uppercase font-bold mb-1">Budget</div>
                      <div className="text-sm font-bold text-gray-900 dark:text-white">{ad.totalCoins.toLocaleString()} 🪙</div>
                      <div className="text-[10px] text-gray-500">spent: {ad.coinsUsed.toLocaleString()}</div>
                    </div>
                    <div className="bg-gray-50 dark:bg-gray-800/50 p-3 rounded-xl">
                      <div className="text-[10px] text-gray-400 uppercase font-bold mb-1">Targeting</div>
                      <div className="text-xs text-gray-700 dark:text-gray-300 font-semibold">
                        {ad.targeting?.gender && ad.targeting.gender !== "all" ? ad.targeting.gender : "All genders"}
                      </div>
                      <div className="text-[10px] text-gray-400">
                        {ad.targeting?.age_min || ad.targeting?.age_max
                          ? `Age ${ad.targeting.age_min || 13}–${ad.targeting.age_max || 65}`
                          : "All ages"}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-gray-800">
                    <div className="text-xs text-gray-400">{ad.createdAt}</div>
                    <div className="flex gap-1" onClick={(e) => e.stopPropagation()}>
                      {renderAdActions(ad, true)}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Empty state */}
            {filteredAds.length === 0 && (
              <div className="p-12 text-center">
                <Megaphone className="w-12 h-12 mx-auto mb-4 text-gray-200 dark:text-gray-800" />
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">No campaigns found</h3>
                <p className="text-gray-500 dark:text-gray-400 mt-1">Try adjusting your filters or search query.</p>
                <button onClick={handleCreateAd}
                  className="mt-4 inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl font-bold text-sm hover:opacity-90 transition-opacity">
                  <Plus className="w-4 h-4" /> Create your first ad
                </button>
              </div>
            )}
          </div>
        )}

        {/* ── Modals ── */}
        {showInactivePopup && (
          <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Vendor verification pending</h3>
              <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">Your vendor account is not yet validated. Please wait for approval.</p>
              <div className="flex justify-center">
                <button onClick={() => setShowInactivePopup(false)} className="px-4 py-2.5 rounded-lg bg-gradient-to-r from-orange-500 to-pink-600 text-white font-medium hover:opacity-90 transition-opacity">OK</button>
              </div>
            </div>
          </div>
        )}
        {showProfileGatePopup && (
          <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Complete your profile first</h3>
              <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center leading-relaxed">
                Your profile is <span className="font-bold text-orange-500">{Math.round(Number(profileCompletion || 0))}%</span> complete.
                You need above <span className="font-bold text-pink-600">80%</span> to upload ads.
              </p>
              <div className="flex justify-center">
                <button onClick={() => setShowProfileGatePopup(false)} className="px-4 py-2.5 rounded-lg bg-gradient-to-r from-orange-500 to-pink-600 text-white font-medium hover:opacity-90 transition-opacity">OK</button>
              </div>
            </div>
          </div>
        )}
        {showAdLimitPopup && (
          <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Upgrade your package</h3>
              <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center leading-relaxed">
                Your package allows <span className="font-bold text-pink-600">{activePackageAdsLimit}</span> ads, and you have <span className="font-bold text-orange-500">{ads.length}</span>. Upgrade to create more.
              </p>
              <div className="flex justify-center">
                <button onClick={() => setShowAdLimitPopup(false)} className="px-4 py-2.5 rounded-lg bg-gradient-to-r from-orange-500 to-pink-600 text-white font-medium hover:opacity-90 transition-opacity">OK</button>
              </div>
            </div>
          </div>
        )}

        <EditContentModal
          isOpen={!!editingAd}
          onClose={() => setEditingAd(null)}
          item={editingAd}
          contentType="ad"
          onSaved={handleAdUpdated}
        />
      </div>
    </div>
  );
}