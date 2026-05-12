import { useState, useEffect, useCallback } from "react";
import { useSelector } from "react-redux";
import { useNavigate, useOutletContext } from "react-router-dom";
import api from "../../lib/api";
import {
  Wallet,
  ArrowUpRight,
  ArrowDownLeft,
  RefreshCw,
  Megaphone,
  BarChart2,
  Clock,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Loader2,
  User,
  X,
} from "lucide-react";

// Helpers
// Coin Icon (replaces INR symbol everywhere)
const CoinIcon = ({ size = 16, className = "" }) => (
  <svg
    width={size} height={size} viewBox="0 0 24 24" fill="none"
    xmlns="http://www.w3.org/2000/svg"
    className={`inline-block flex-shrink-0 ${className}`}
    style={{ verticalAlign: "-0.15em" }}
  >
    <circle cx="12" cy="12" r="10" fill="#F59E0B" />
    <circle cx="12" cy="12" r="8" fill="#FBBF24" />
    <circle cx="12" cy="12" r="6.5" fill="none" stroke="#D97706" strokeWidth="0.8" />
    <text x="12" y="16" textAnchor="middle" fontSize="9" fontWeight="bold" fill="#92400E" fontFamily="serif">&#8377;</text>
  </svg>
);

const formatCurrencyNum = (amount) => {
  if (amount == null) return "-";
  return new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  }).format(amount);
};

const formatMetric = (value) => {
  const num = Number(value || 0);
  if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
  if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
  return `${num}`;
};

const getApiOrigin = () => {
  const base = String(api?.defaults?.baseURL || "").trim();
  if (!base) return "";
  return base.replace(/\/api\/?$/i, "");
};

const IMAGE_EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp", "gif", "bmp", "svg", "avif"]);
const NON_IMAGE_EXTENSIONS = new Set(["m3u8", "mpd", "ts", "mp4", "webm", "mov", "mkv"]);

const getFileExt = (urlValue) => {
  const str = String(urlValue || "").trim();
  if (!str) return "";
  const pathPart = str.split("?")[0].split("#")[0];
  const parts = pathPart.split(".");
  if (parts.length < 2) return "";
  return parts[parts.length - 1].toLowerCase();
};

const isRenderableImageUrl = (urlValue) => {
  const ext = getFileExt(urlValue);
  if (!ext) return true;
  if (NON_IMAGE_EXTENSIONS.has(ext)) return false;
  if (IMAGE_EXTENSIONS.has(ext)) return true;
  return true;
};

const buildThumbnailCandidates = (rawUrl) => {
  const value = String(rawUrl || "").trim();
  if (!value) return [];

  const normalized = value.replace(/\\/g, "/");
  const apiOrigin = getApiOrigin();
  const set = new Set();

  if (/^https?:\/\//i.test(normalized)) set.add(normalized);
  if (normalized.startsWith("//")) {
    set.add(`https:${normalized}`);
    set.add(`http:${normalized}`);
  }
  if (apiOrigin) {
    if (normalized.startsWith("/")) set.add(`${apiOrigin}${normalized}`);
    if (normalized.startsWith("uploads/")) set.add(`${apiOrigin}/${normalized}`);
    const fileName = normalized.split("/").filter(Boolean).pop();
    if (fileName) set.add(`${apiOrigin}/uploads/${fileName}`);
  }
  if (normalized.startsWith("/")) set.add(normalized);

  return Array.from(set).filter(isRenderableImageUrl);
};

const formatDate = (dateStr) => {
  if (!dateStr) return "-";
  return new Date(dateStr).toLocaleString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

const formatTimeAgo = (dateStr) => {
  if (!dateStr) return "";
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
};

// Sub-components


const DashboardInfoCard = ({
  className,
  badge,
  title,
  subtitle,
  secondaryBadge,
  footer,
  onClick,
  loading,
  children,
  highlight = false,
}) => (
  <div
    onClick={onClick}
    className={`rounded-2xl p-5 border transition-all duration-300 h-full min-h-[240px] flex flex-col ${onClick ? "cursor-pointer hover:scale-[1.01] hover:shadow-xl" : ""} ${className}`}
  >
    <div className="flex items-start justify-between gap-2">
      <div className="min-w-0">
        {loading ? (
          <div className={`h-7 w-32 rounded-lg animate-pulse ${highlight ? "bg-white/20" : "bg-gray-100 dark:bg-gray-800"}`} />
        ) : (
          <h3 className="text-4xl md:text-3xl font-bold leading-none truncate">{title}</h3>
        )}
        {subtitle ? <p className={`text-base mt-1 font-medium ${highlight ? "text-white/90" : "text-gray-500 dark:text-gray-400"}`}>{subtitle}</p> : null}
        {secondaryBadge ? (
          <span className={`inline-flex mt-2 text-[11px] font-semibold px-2.5 py-1 rounded-full ${highlight ? "bg-white/20 text-white" : "bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400"}`}>
            {secondaryBadge}
          </span>
        ) : null}
      </div>
     
    </div>
    {children ? <div className="mt-4 flex-1">{children}</div> : <div className="flex-1" />}
    {footer ? <div className={`mt-4 text-sm font-semibold text-right ${highlight ? "text-white/80" : "text-pink-600 dark:text-pink-400"}`}>{footer}</div> : null}
  </div>
);

const DirectionBadge = ({ direction }) => (
  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold ${
    direction === "credit"
      ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
      : "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
  }`}>
    {direction === "credit" ? <ArrowDownLeft className="w-3 h-3" /> : <ArrowUpRight className="w-3 h-3" />}
    {direction === "credit" ? "Credit" : "Debit"}
  </span>
);

const StatusIcon = ({ status }) => {
  if (status === "SUCCESS") return <CheckCircle2 className="w-4 h-4 text-green-500" />;
  if (status === "FAILED") return <XCircle className="w-4 h-4 text-red-500" />;
  return <Clock className="w-4 h-4 text-amber-500" />;
};

const TransactionRow = ({ tx }) => (
  <tr className="group hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
    <td className="px-4 py-3">
      <div className="flex items-center gap-3">
        <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${
          tx.direction === "credit"
            ? "bg-green-100 dark:bg-green-900/30"
            : "bg-red-100 dark:bg-red-900/30"
        }`}>
          {tx.direction === "credit"
            ? <ArrowDownLeft className="w-4 h-4 text-green-600 dark:text-green-400" />
            : <ArrowUpRight className="w-4 h-4 text-red-600 dark:text-red-400" />
          }
        </div>
        <div>
          <div className="text-sm font-semibold text-gray-900 dark:text-white leading-tight">
            {tx.label || tx.type || "Transaction"}
          </div>
          {tx.description && (
            <div className="text-xs text-gray-400 dark:text-gray-500 mt-0.5 max-w-[200px] truncate">
              {tx.description}
            </div>
          )}
          {tx.ad?.title && (
            <div className="text-xs text-pink-500 mt-0.5 truncate max-w-[180px]">Ad: {tx.ad.title}</div>
          )}
        </div>
      </div>
    </td>
    <td className="px-4 py-3">
      <span className={`text-sm font-bold flex items-center gap-0.5 ${
        tx.direction === "credit" ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"
      }`}>
        {tx.direction === "credit" ? "+" : "-"}<CoinIcon size={13} />{Number(tx.amount).toLocaleString("en-IN")}
      </span>
    </td>
    <td className="px-4 py-3">
      <DirectionBadge direction={tx.direction} />
    </td>
    <td className="px-4 py-3">
      <div className="flex items-center gap-1.5">
        <StatusIcon status={tx.status} />
        <span className="text-xs font-semibold text-gray-600 dark:text-gray-400">{tx.status}</span>
      </div>
    </td>
    <td className="px-4 py-3 text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">
      {formatDate(tx.created_at)}
    </td>
  </tr>
);

const AdThumbnail = ({ thumbnail, caption }) => {
  const sources = buildThumbnailCandidates(thumbnail);
  const [index, setIndex] = useState(0);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setIndex(0);
    setFailed(false);
  }, [thumbnail]);

  if (!sources.length || failed) {
    return (
      <div className="w-full h-full flex items-center justify-center text-[10px] text-gray-400">
        No Image
      </div>
    );
  }

  return (
    <img
      src={sources[index]}
      alt={caption || "Ad"}
      className="w-full h-full object-cover"
      loading="lazy"
      onError={() => {
        if (index < sources.length - 1) {
          setIndex((prev) => prev + 1);
        } else {
          setFailed(true);
        }
      }}
    />
  );
};

// Main Component

export default function VendorDashboard() {
  const navigate = useNavigate();
  const { handleOpenCreateModal } = useOutletContext() || {};
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;

  // Wallet state
  const [wallet, setWallet] = useState(null);
  const [transactions, setTransactions] = useState([]);
  const [total, setTotal] = useState(0);
  const [walletLoading, setWalletLoading] = useState(true);
  const [walletError, setWalletError] = useState(null);

  // Active ads count
  const [dashboardSummary, setDashboardSummary] = useState(null);
  const [dashboardLoading, setDashboardLoading] = useState(true);

  // Profile completion
  const [profilePct, setProfilePct] = useState(null);
  const [dismissedBanner, setDismissedBanner] = useState(
    () => sessionStorage.getItem("profileBannerDismissed") === "1"
  );

  // Fetch wallet and history
  const fetchWalletData = useCallback(async () => {
    if (!userId) return;
    setWalletLoading(true);
    setWalletError(null);
    try {
      // /api/wallet/me - basic wallet + transaction history
      const res = await api.get("/wallet/me", { params: { limit: 7 } });
      setWallet(res.data.wallet);
      setTotal(res.data.total || 0);

      // /api/wallet/vendor/{userId}/history - detailed transactions with filters
      const histRes = await api.get(`/wallet/vendor/${userId}/history`, { params: { limit: 7 } });
      setTransactions(histRes.data.transactions || []);
      if (histRes.data.total != null) setTotal(histRes.data.total);
    } catch (err) {
      console.error("Wallet fetch error:", err);
      setWalletError(err?.response?.data?.message || "Failed to load wallet data");
    } finally {
      setWalletLoading(false);
    }
  }, [userId]);

  // Fetch dashboard summary
  const fetchDashboardSummary = useCallback(async () => {
    if (!userId) return;
    setDashboardLoading(true);
    try {
      const res = await api.get(`/vendors/dashboard/${userId}`);
      setDashboardSummary(res.data || null);
      setProfilePct(res.data?.vendor?.profile_completion_percentage ?? null);
    } catch (err) {
      console.error("Dashboard summary fetch error:", err);
      setDashboardSummary(null);
      setProfilePct(null);
    } finally {
      setDashboardLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    fetchWalletData();
  }, [fetchWalletData]);

  useEffect(() => {
    fetchDashboardSummary();
  }, [fetchDashboardSummary]);

  // Derived stats
  const totalDebited = transactions
    .filter((t) => t.direction === "debit")
    .reduce((sum, t) => sum + Number(t.amount || 0), 0);

  const totalCredited = transactions
    .filter((t) => t.direction === "credit")
    .reduce((sum, t) => sum + Number(t.amount || 0), 0);

  const recentActivity = transactions.slice(0, 5);
  const vendorName =
    dashboardSummary?.vendor?.company_name ||
    userObject?.full_name ||
    userObject?.username ||
    "Vendor";
  const isVendorVerified = !!dashboardSummary?.vendor?.validated;
  const activeAdsCount = Number(dashboardSummary?.ads?.active_count || 0);
  const activePackage = dashboardSummary?.package || null;
  const salesOfficer = dashboardSummary?.sales_officer || null;
  const packageName = activePackage?.name || "No Active Package";
  const packageStatus = activePackage?.status === "active" ? "Active" : "Inactive";
  const adsRemainingText = activePackage ? `${Math.max(0, Number(activePackage?.ads_remaining || 0))}` : "-";
  const daysLeftText = activePackage
    ? (activePackage?.days_left == null ? "-" : `${Math.max(0, Number(activePackage.days_left))}`)
    : "-";
  const totalAdsCount = Number(dashboardSummary?.ads?.total_count || 0);
  const inactiveAdsCount = Math.max(0, totalAdsCount - activeAdsCount);
  const profileCompletionText = profilePct == null ? "-" : `${Math.max(0, Math.min(100, Number(profilePct || 0)))}% Complete`;
  const vendorRegisteredName = dashboardSummary?.vendor?.registered_name || "-";
  const overview = dashboardSummary?.overview || {};
  const popularAds = Array.isArray(dashboardSummary?.popular_ads) ? dashboardSummary.popular_ads : [];

  // Render
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">

        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-lg flex items-center justify-center bg-gradient-to-tr from-orange-400 via-red-500 to-pink-600 text-white shadow-sm">
                <Megaphone className="w-4 h-4" />
              </div>
              <span className="text-xs font-bold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Vendor Portal
              </span>
            </div>
            <h1 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white tracking-tight">
              Ad Dashboard
            </h1>
            <p className="text-gray-500 dark:text-gray-400 text-sm mt-1">
              {vendorName} · Wallet & Performance Overview
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => { fetchWalletData(); fetchDashboardSummary(); }}
              className="p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              title="Refresh"
            >
              <RefreshCw className="w-4 h-4 text-gray-500" />
            </button>
            <button
              onClick={() => handleOpenCreateModal ? handleOpenCreateModal('ad') : navigate("/vendor/ads-management")}
              className="bg-gradient-to-r from-purple-600 via-pink-600 to-orange-500 text-white font-semibold rounded-xl px-6 py-3 text-sm flex items-center gap-2 shadow-lg shadow-pink-500/20 hover:shadow-pink-500/30 hover:-translate-y-0.5 transition-all"
            >
              <span className="text-lg leading-none">+</span>
              Create New Ad
            </button>
          </div>
        </div>

        {/* Error Banner */}
        {walletError && (
          <div className="mb-6 flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium border bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 border-red-200 dark:border-red-800">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{walletError}</span>
            <button onClick={fetchWalletData} className="ml-auto underline text-xs">Retry</button>
          </div>
        )}

        {/* Profile Completion Banner */}
        {profilePct !== null && profilePct < 100 && !dismissedBanner && (
          <div className="mb-6 rounded-2xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-900/20 overflow-hidden">
            <div className="flex items-start gap-4 px-5 py-4">
              <div className="w-10 h-10 rounded-xl bg-amber-100 dark:bg-amber-800/50 flex items-center justify-center flex-shrink-0">
                <User className="w-5 h-5 text-amber-600 dark:text-amber-400" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between gap-4 mb-1">
                  <div>
                    <span className="text-sm font-bold text-amber-800 dark:text-amber-300">
                      Complete your vendor profile - {profilePct}% done
                    </span>
                    <p className="text-xs text-amber-600 dark:text-amber-400 mt-0.5">
                      A complete profile is required for account verification and to start running ads.
                    </p>
                  </div>
                  <button
                    onClick={() => { setDismissedBanner(true); sessionStorage.setItem("profileBannerDismissed", "1"); }}
                    className="p-1.5 rounded-lg hover:bg-amber-100 dark:hover:bg-amber-800/50 transition-colors flex-shrink-0"
                  >
                    <X className="w-4 h-4 text-amber-500" />
                  </button>
                </div>
                {/* Progress bar */}
                <div className="mt-2 flex items-center gap-3">
                  <div className="flex-1 h-2 rounded-full bg-amber-200 dark:bg-amber-800 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-amber-500 to-orange-500 transition-all duration-700"
                      style={{ width: `${profilePct}%` }}
                    />
                  </div>
                  <button
                    onClick={() => navigate("/vendor/profile")}
                    className="flex-shrink-0 text-xs font-bold px-3 py-1.5 rounded-lg bg-amber-600 dark:bg-amber-500 text-white hover:opacity-90 transition-opacity"
                  >
                    Complete Profile -&gt;
                  </button>
                </div>
              </div>
            </div>

            {/* Pagination */}
          </div>
        )}


        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <DashboardInfoCard
            className="bg-white dark:bg-gray-900 border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700 text-gray-900 dark:text-white"
            badge={isVendorVerified ? "Verified" : "Pending"}
            title={vendorName}
            subtitle="Vendor Profile"
            secondaryBadge={isVendorVerified ? "Verified" : "Pending"}
            footer="View ->>"
            loading={dashboardLoading}
            onClick={() => navigate("/vendor/profile")}
          >
            <div className="space-y-2 text-sm font-medium text-gray-500 dark:text-gray-400">
              <div className="flex items-center justify-between gap-3">
                <span>Registered Name</span>
                <span className="text-gray-800 dark:text-gray-200 truncate max-w-[55%] text-right">{vendorRegisteredName}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>Profile Completion</span>
                <span className="text-gray-800 dark:text-gray-200">{profileCompletionText}</span>
              </div>
            </div>
          </DashboardInfoCard>

          <DashboardInfoCard
            className="bg-white dark:bg-gray-900 border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700 text-gray-900 dark:text-white"
            badge={packageStatus}
            title={packageName}
            subtitle="Package Details"
            secondaryBadge="Verified"
            footer="View ->>"
            loading={dashboardLoading}
            onClick={() => navigate("/vendor/billing")}
          >
            <div className="grid grid-cols-2 gap-3">
              <div>
                <div className="text-4xl md:text-3xl font-bold leading-none">{adsRemainingText}</div>
                <div className="text-sm mt-1 font-medium opacity-90">Ads Remain</div>
              </div>
              <div>
                <div className="text-4xl md:text-3xl font-bold leading-none">{daysLeftText}</div>
                <div className="text-sm mt-1 font-medium opacity-90">Days Left</div>
              </div>
            </div>
          </DashboardInfoCard>

          <DashboardInfoCard
            className="bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] text-white border-transparent shadow-lg shadow-pink-500/20"
            badge="Running"
            title={`${activeAdsCount}`}
            subtitle="Active Ads"
            secondaryBadge="Verified"
            footer="View ->"
            loading={dashboardLoading}
            onClick={() => navigate("/vendor/ads-management")}
            highlight
          >
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div>
                <div className="text-2xl font-bold leading-none">{totalAdsCount}</div>
                <div className="mt-1 text-white/80">Total Ads</div>
              </div>
              <div>
                <div className="text-2xl font-bold leading-none">{inactiveAdsCount}</div>
                <div className="mt-1 text-white/80">Inactive Ads</div>
              </div>
            </div>
          </DashboardInfoCard>

          <DashboardInfoCard
            className="bg-white dark:bg-gray-900 border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700 text-gray-900 dark:text-white"
            badge="View ->>"
            title={salesOfficer?.full_name || "Not Assigned"}
            subtitle="Sales Officer"
            secondaryBadge="Verified"
            loading={dashboardLoading}
          >
            <div className="space-y-2 text-sm">
              <div className="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">Contact Details</div>
              <div className="font-semibold">{salesOfficer?.phone || "-"}</div>
              <div className="break-all font-semibold">{salesOfficer?.email || "-"}</div>
              <div className="text-xs text-gray-500 dark:text-gray-400 pt-1">Location: {salesOfficer?.location || "-"}</div>
            </div>
          </DashboardInfoCard>
        </div>
        <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 p-4 mb-6 shadow-sm">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
            <div className="rounded-xl px-4 py-3 bg-gradient-to-r from-indigo-600 to-violet-500 text-white">
              <div className="text-[11px] font-semibold opacity-90">Followers</div>
              <div className="text-3xl font-bold leading-tight mt-0.5">{formatMetric(overview.followers)}</div>
            </div>
            <div className="rounded-xl px-4 py-3 bg-gradient-to-r from-blue-700 to-blue-500 text-white">
              <div className="text-[11px] font-semibold opacity-90">Views</div>
              <div className="text-3xl font-bold leading-tight mt-0.5">{formatMetric(overview.views)}</div>
            </div>
            <div className="rounded-xl px-4 py-3 bg-gradient-to-r from-sky-600 to-cyan-500 text-white">
              <div className="text-[11px] font-semibold opacity-90">Reach</div>
              <div className="text-3xl font-bold leading-tight mt-0.5">{formatMetric(overview.reach)}</div>
            </div>
            <div className="rounded-xl px-4 py-3 bg-gradient-to-r from-emerald-600 to-teal-500 text-white">
              <div className="text-[11px] font-semibold opacity-90">Engagements</div>
              <div className="text-3xl font-bold leading-tight mt-0.5">{formatMetric(overview.engagements)}</div>
            </div>
            <div className="rounded-xl px-4 py-3 bg-gradient-to-r from-pink-600 to-rose-500 text-white">
              <div className="text-[11px] font-semibold opacity-90">Website Clicks</div>
              <div className="text-3xl font-bold leading-tight mt-0.5">{formatMetric(overview.website_clicks)}</div>
            </div>
            <div className="rounded-xl px-4 py-3 bg-gradient-to-r from-fuchsia-700 to-purple-500 text-white">
              <div className="text-[11px] font-semibold opacity-90">Profile Link Clicks</div>
              <div className="text-3xl font-bold leading-tight mt-0.5">{formatMetric(overview.profile_link_clicks)}</div>
            </div>
          </div>
        </div>
        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Most Popular Ads */}
          <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 dark:border-gray-800">
              <div>
                <h2 className="text-lg font-bold text-gray-900 dark:text-white">Most Popular Ads</h2>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{popularAds.length} items</p>
              </div>
              <span className="text-xs font-semibold text-pink-600 dark:text-pink-400">View --&gt;</span>
            </div>

            <div className="overflow-x-auto">
              {dashboardLoading ? (
                <div className="flex flex-col items-center justify-center py-16 gap-3">
                  <Loader2 className="w-8 h-8 animate-spin text-cyan-500" />
                  <span className="text-sm text-gray-500 dark:text-gray-400">Loading ads...</span>
                </div>
              ) : popularAds.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16 gap-3">
                  <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                    <BarChart2 className="w-7 h-7 text-gray-400" />
                  </div>
                  <p className="text-sm font-medium text-gray-500 dark:text-gray-400">No ad analytics available</p>
                </div>
              ) : (
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Thumbnail</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Caption</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Published At</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Type</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Views</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Engagements</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Likes</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Comments</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Shares</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Saves</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                    {popularAds.map((ad) => (
                      <tr key={ad.ad_id} className="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                        <td className="px-4 py-3">
                          <div className="w-14 h-14 rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800">
                            <AdThumbnail thumbnail={ad.thumbnail} caption={ad.caption} />
                          </div>
                        </td>
                        <td className="px-4 py-3 text-sm font-medium text-gray-800 dark:text-gray-200 max-w-[220px] truncate">
                          {ad.caption || "-"}
                        </td>
                        <td className="px-4 py-3 text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">
                          {formatDate(ad.published_at)}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-700 dark:text-gray-300 whitespace-nowrap">{ad.type || "-"}</td>
                        <td className="px-4 py-3 text-sm font-semibold text-blue-600 dark:text-blue-400">{Number(ad.views || 0).toLocaleString("en-IN")}</td>
                        <td className="px-4 py-3 text-sm font-semibold text-violet-600 dark:text-violet-400">{Number(ad.engagements || 0).toLocaleString("en-IN")}</td>
                        <td className="px-4 py-3 text-sm font-semibold text-sky-600 dark:text-sky-400">{Number(ad.likes || 0).toLocaleString("en-IN")}</td>
                        <td className="px-4 py-3 text-sm font-semibold text-rose-600 dark:text-rose-400">{Number(ad.comments || 0).toLocaleString("en-IN")}</td>
                        <td className="px-4 py-3 text-sm font-semibold text-emerald-600 dark:text-emerald-400">{Number(ad.shares || 0).toLocaleString("en-IN")}</td>
                        <td className="px-4 py-3 text-sm font-semibold text-cyan-600 dark:text-cyan-400">{Number(ad.saves || 0).toLocaleString("en-IN")}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
          {/* Right Panel */}
          <div className="flex flex-col gap-6">

            {/* Wallet Balance Card */}
            <div className="rounded-2xl p-6 bg-gradient-to-br from-gray-900 to-black text-white relative overflow-hidden border border-gray-800">
              <div className="absolute top-0 right-0 w-48 h-48 bg-pink-600/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
              <div className="relative z-10">
                <div className="flex items-center gap-2 mb-4">
                  <Wallet className="w-4 h-4 text-pink-400" />
                  <span className="text-xs font-bold uppercase tracking-wider text-gray-400">My Wallet</span>
                </div>
                {walletLoading ? (
                  <div className="h-10 w-36 rounded-lg bg-white/10 animate-pulse mb-1" />
                ) : (
                  <div className="text-4xl font-black mb-1">
                    {wallet ? formatCurrencyNum(wallet.balance) : "-"}
                  </div>
                )}
                <div className="text-xs text-gray-400 font-medium">Available Balance</div>

                <div className="mt-5 grid grid-cols-2 gap-3">
                  <div className="p-3 rounded-xl bg-white/5">
                    <div className="text-[10px] font-bold uppercase tracking-wider text-green-400 mb-1">Credited</div>
                    <div className="text-lg font-extrabold">
                      {walletLoading ? "-" : <span className="flex items-center gap-0.5"><CoinIcon size={15} />{totalCredited.toLocaleString("en-IN")}</span>}
                    </div>
                  </div>
                  <div className="p-3 rounded-xl bg-white/5">
                    <div className="text-[10px] font-bold uppercase tracking-wider text-red-400 mb-1">Debited</div>
                    <div className="text-lg font-extrabold">
                      {walletLoading ? "-" : <span className="flex items-center gap-0.5"><CoinIcon size={15} />{totalDebited.toLocaleString("en-IN")}</span>}
                    </div>
                  </div>
                </div>

                <button
                  onClick={() => navigate("/vendor/billing")}
                  className="mt-4 w-full py-2.5 rounded-xl bg-gradient-to-r from-pink-600 to-orange-500 text-white text-sm font-bold hover:opacity-90 transition-opacity"
                >
                  <CoinIcon size={16} className="mr-1" /> Recharge Wallet
                </button>
              </div>
            </div>

            {/* Recent Activity */}
            <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm flex-1">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-xs font-bold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  Recent Activity
                </h3>
                <span className="text-xs text-gray-400 dark:text-gray-500">{recentActivity.length} items</span>
              </div>

              {walletLoading ? (
                <div className="flex flex-col gap-3">
                  {[1, 2, 3].map((i) => (
                    <div key={i} className="h-12 rounded-xl bg-gray-100 dark:bg-gray-800 animate-pulse" />
                  ))}
                </div>
              ) : recentActivity.length === 0 ? (
                <div className="text-center py-8 text-sm text-gray-400">No recent activity</div>
              ) : (
                <div className="flex flex-col gap-1">
                  {recentActivity.map((tx) => (
                    <div
                      key={tx._id}
                      className="flex items-start gap-3 rounded-xl p-2.5 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer"
                    >
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                        tx.direction === "credit"
                          ? "bg-green-100 dark:bg-green-900/30"
                          : "bg-red-100 dark:bg-red-900/30"
                      }`}>
                        {tx.direction === "credit"
                          ? <ArrowDownLeft className="w-3.5 h-3.5 text-green-600 dark:text-green-400" />
                          : <ArrowUpRight className="w-3.5 h-3.5 text-red-600 dark:text-red-400" />
                        }
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-semibold text-gray-800 dark:text-gray-200 leading-snug truncate">
                          {tx.label || tx.type || "Transaction"}
                        </p>
                        <div className="flex items-center justify-between mt-0.5">
                          <span className={`text-xs font-bold flex items-center gap-0.5 ${tx.direction === "credit" ? "text-green-600" : "text-red-600"}`}>
                            {tx.direction === "credit" ? "+" : "-"}<CoinIcon size={12} />{Number(tx.amount).toLocaleString("en-IN")}
                          </span>
                          <span className="text-[10px] text-gray-400">{formatTimeAgo(tx.created_at)}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

          </div>
        </div>

      </div>
    </div>
  );
}
