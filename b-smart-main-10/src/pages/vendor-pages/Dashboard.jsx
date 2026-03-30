import { useState, useEffect, useCallback, createElement } from "react";
import { useSelector } from "react-redux";
import { useNavigate, useOutletContext } from "react-router-dom";
import api from "../../lib/api";
import {
  Wallet,
  TrendingUp,
  TrendingDown,
  ArrowUpRight,
  ArrowDownLeft,
  RefreshCw,
  Filter,
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

// ─── Coin Icon (replaces ₹ symbol everywhere) ─────────────────────────────────
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
  if (amount == null) return "—";
  return new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  }).format(amount);
};

const formatDate = (dateStr) => {
  if (!dateStr) return "—";
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

// ─── Sub-components ───────────────────────────────────────────────────────────

const MetricCard = ({ label, value, icon, sublabel, onClick, highlight, loading }) => (
  <div
    onClick={onClick}
    className={`relative cursor-pointer rounded-2xl p-5 flex flex-col gap-3 transition-all duration-300 hover:scale-[1.02] hover:shadow-xl border ${
      highlight
        ? "bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] text-white border-transparent shadow-lg shadow-pink-500/20"
        : "bg-white dark:bg-gray-900 border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700"
    }`}
  >
    <div className="flex items-center justify-between">
      <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${highlight ? "bg-white/20" : "bg-gray-100 dark:bg-gray-800"}`}>
        {icon
          ? createElement(icon, { className: `w-5 h-5 ${highlight ? "text-white" : "text-gray-600 dark:text-gray-300"}` })
          : null}
      </div>
      <span className={`text-xs font-semibold px-2 py-1 rounded-full ${highlight ? "bg-white/20 text-white" : "bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400"}`}>
        {sublabel}
      </span>
    </div>
    <div>
      {loading ? (
        <div className={`h-8 w-24 rounded-lg animate-pulse ${highlight ? "bg-white/20" : "bg-gray-100 dark:bg-gray-800"}`} />
      ) : (
        <div className={`text-3xl font-bold tracking-tight ${highlight ? "text-white" : "text-gray-900 dark:text-white"}`}>
          {value}
        </div>
      )}
      <div className={`text-sm mt-1 font-medium ${highlight ? "text-white/90" : "text-gray-500 dark:text-gray-400"}`}>
        {label}
      </div>
    </div>
    {onClick && (
      <div className={`absolute bottom-4 right-4 text-xs font-semibold opacity-60 hover:opacity-100 transition-opacity ${highlight ? "text-white" : "text-pink-600 dark:text-pink-400"}`}>
        View →
      </div>
    )}
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
            <div className="text-xs text-pink-500 mt-0.5 truncate max-w-[180px]">📢 {tx.ad.title}</div>
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

const TRANSACTION_TYPES = ["", "AD_SPEND", "RECHARGE", "REFUND", "BONUS"];
const DIRECTIONS = ["", "credit", "debit"];

// ─── Main Component ───────────────────────────────────────────────────────────

export default function VendorDashboard() {
  const navigate = useNavigate();
  const { handleOpenCreateModal } = useOutletContext() || {};
  const { userObject } = useSelector((state) => state.auth);

  // Wallet state
  const [wallet, setWallet] = useState(null);
  const [transactions, setTransactions] = useState([]);
  const [total, setTotal] = useState(0);
  const [walletLoading, setWalletLoading] = useState(true);
  const [walletError, setWalletError] = useState(null);

  // Active ads count
  const [activeAdsCount, setActiveAdsCount] = useState(null);
  const [adsLoading, setAdsLoading] = useState(true);

  // Profile completion
  const [profilePct, setProfilePct] = useState(null);
  const [dismissedBanner, setDismissedBanner] = useState(
    () => sessionStorage.getItem("profileBannerDismissed") === "1"
  );

  // Filters
  const [typeFilter, setTypeFilter] = useState("");
  const [directionFilter, setDirectionFilter] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [showFilters, setShowFilters] = useState(false);

  // ─── Fetch Wallet & History ───────────────────────────────────────────────
  const fetchWalletData = useCallback(async () => {
    if (!userObject?._id) return;
    setWalletLoading(true);
    setWalletError(null);
    try {
      const params = { limit: 7 };
      if (typeFilter) params.type = typeFilter;
      if (directionFilter) params.direction = directionFilter;
      if (startDate) params.startDate = startDate;
      if (endDate) params.endDate = endDate;

      // /api/wallet/me — basic wallet + transaction history
      const res = await api.get("/wallet/me", { params });
      setWallet(res.data.wallet);
      setTotal(res.data.total || 0);

      // /api/wallet/vendor/{userId}/history — detailed transactions with filters
      const histParams = { limit: 7 };
      if (typeFilter) histParams.type = typeFilter;
      if (directionFilter) histParams.direction = directionFilter;
      if (startDate) histParams.startDate = startDate;
      if (endDate) histParams.endDate = endDate;

      const histRes = await api.get(`/wallet/vendor/${userObject._id}/history`, { params: histParams });
      setTransactions(histRes.data.transactions || []);
      if (histRes.data.total != null) setTotal(histRes.data.total);
    } catch (err) {
      console.error("Wallet fetch error:", err);
      setWalletError(err?.response?.data?.message || "Failed to load wallet data");
    } finally {
      setWalletLoading(false);
    }
  }, [userObject?._id, typeFilter, directionFilter, startDate, endDate]);

  // ─── Fetch Active Ads Count ───────────────────────────────────────────────
  const fetchActiveAds = useCallback(async () => {
    if (!userObject?._id) return;
    setAdsLoading(true);
    try {
      const res = await api.get(`/ads/user/${userObject._id}`);
      const ads = res.data?.ads || res.data || [];
      const active = Array.isArray(ads)
        ? ads.filter((ad) => (ad.status || "").toLowerCase() === "active").length
        : 0;
      setActiveAdsCount(active);
    } catch (err) {
      console.error("Ads fetch error:", err);
      setActiveAdsCount(0);
    } finally {
      setAdsLoading(false);
    }
  }, [userObject?._id]);

  useEffect(() => {
    fetchWalletData();
  }, [fetchWalletData]);

  useEffect(() => {
    fetchActiveAds();
  }, [fetchActiveAds]);

  // ─── Fetch Profile Completion ──────────────────────────────────────────
  useEffect(() => {
    if (!userObject?._id) return;
    api.get(`/vendors/profile/${userObject._id}`)
      .then(res => setProfilePct(res.data?.profile_completion_percentage ?? null))
      .catch(() => {});
  }, [userObject?._id]);

  // ─── Derived stats ────────────────────────────────────────────────────────
  const totalDebited = transactions
    .filter((t) => t.direction === "debit")
    .reduce((sum, t) => sum + Number(t.amount || 0), 0);

  const totalCredited = transactions
    .filter((t) => t.direction === "credit")
    .reduce((sum, t) => sum + Number(t.amount || 0), 0);

  const recentActivity = transactions.slice(0, 5);

  const handleApplyFilters = () => {
    fetchWalletData();
  };

  const handleClearFilters = () => {
    setTypeFilter("");
    setDirectionFilter("");
    setStartDate("");
    setEndDate("");
  };

  // ─── Render ───────────────────────────────────────────────────────────────
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
              {userObject?.full_name || userObject?.username || "Vendor"} · Wallet & Performance Overview
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => { fetchWalletData(); fetchActiveAds(); }}
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
                      Complete your vendor profile — {profilePct}% done
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
                    Complete Profile →
                  </button>
                </div>
              </div>
            </div>

            {/* Pagination */}
          </div>
        )}


        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <MetricCard
            label="Active Ads"
            value={activeAdsCount != null ? activeAdsCount.toLocaleString() : "—"}
            icon={Megaphone}
            sublabel="Running"
            onClick={() => navigate("/vendor/ads-management")}
            highlight
            loading={adsLoading}
          />
          <MetricCard
            label="Wallet Balance"
            value={wallet ? <span className="flex items-center gap-1"><CoinIcon size={22} />{formatCurrencyNum(wallet.balance)}</span> : "—"}
            icon={Wallet}
            sublabel="Available"
            onClick={() => navigate("/vendor/billing")}
            loading={walletLoading}
          />
          <MetricCard
            label="Total Credited"
            value={walletLoading ? "—" : <span className="flex items-center gap-1"><CoinIcon size={22} />{totalCredited.toLocaleString("en-IN")}</span>}
            icon={TrendingUp}
            sublabel="This Page"
            loading={walletLoading}
          />
          <MetricCard
            label="Total Debited"
            value={walletLoading ? "—" : <span className="flex items-center gap-1"><CoinIcon size={22} />{totalDebited.toLocaleString("en-IN")}</span>}
            icon={TrendingDown}
            sublabel="This Page"
            loading={walletLoading}
          />
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* Wallet History Table */}
          <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            {/* Table Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 dark:border-gray-800">
              <div>
                <h2 className="text-lg font-bold text-gray-900 dark:text-white">Wallet History</h2>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{total} total transactions</p>
              </div>
              <button
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 text-xs font-semibold px-3 py-1.5 rounded-full border transition-colors ${
                  showFilters
                    ? "bg-pink-50 dark:bg-pink-900/20 text-pink-600 dark:text-pink-400 border-pink-200 dark:border-pink-800"
                    : "bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700 hover:border-gray-300"
                }`}
              >
                <Filter className="w-3 h-3" />
                Filters {(typeFilter || startDate || endDate) ? "●" : ""}
              </button>
            </div>

            {/* Filters Row */}
            {showFilters && (
              <div className="px-6 py-4 bg-gray-50 dark:bg-gray-800/50 border-b border-gray-100 dark:border-gray-800">
                <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                  <div>
                    <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Type</label>
                    <select
                      value={typeFilter}
                      onChange={(e) => setTypeFilter(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none focus:ring-2 focus:ring-pink-500/20"
                    >
                      {TRANSACTION_TYPES.map((t) => (
                        <option key={t} value={t}>{t || "All Types"}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Direction</label>
                    <select
                      value={directionFilter}
                      onChange={(e) => setDirectionFilter(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none focus:ring-2 focus:ring-pink-500/20"
                    >
                      {DIRECTIONS.map((d) => (
                        <option key={d} value={d}>{d ? d[0].toUpperCase() + d.slice(1) : "All Directions"}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Start Date</label>
                    <input
                      type="date"
                      value={startDate}
                      onChange={(e) => setStartDate(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none focus:ring-2 focus:ring-pink-500/20"
                    />
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">End Date</label>
                    <input
                      type="date"
                      value={endDate}
                      onChange={(e) => setEndDate(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none focus:ring-2 focus:ring-pink-500/20"
                    />
                  </div>
                  <div className="flex items-end gap-2">
                    <button
                      onClick={handleApplyFilters}
                      className="flex-1 py-2 rounded-xl bg-gradient-to-r from-pink-600 to-orange-500 text-white text-xs font-bold hover:opacity-90 transition-opacity"
                    >
                      Apply
                    </button>
                    <button
                      onClick={handleClearFilters}
                      className="flex-1 py-2 rounded-xl border border-gray-200 dark:border-gray-700 text-xs font-bold hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-gray-600 dark:text-gray-300"
                    >
                      Clear
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Table */}
            <div className="overflow-x-auto">
              {walletLoading ? (
                <div className="flex flex-col items-center justify-center py-16 gap-3">
                  <Loader2 className="w-8 h-8 animate-spin text-pink-500" />
                  <span className="text-sm text-gray-500 dark:text-gray-400">Loading transactions…</span>
                </div>
              ) : transactions.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16 gap-3">
                  <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                    <BarChart2 className="w-7 h-7 text-gray-400" />
                  </div>
                  <p className="text-sm font-medium text-gray-500 dark:text-gray-400">No transactions found</p>
                  {(typeFilter || startDate || endDate) && (
                    <button onClick={handleClearFilters} className="text-xs text-pink-500 underline">Clear filters</button>
                  )}
                </div>
              ) : (
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Transaction</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Amount</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Direction</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Status</th>
                      <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">Date</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                    {transactions.map((tx) => (
                      <TransactionRow key={tx._id} tx={tx} />
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
                    {wallet ? formatCurrencyNum(wallet.balance) : "—"}
                  </div>
                )}
                <div className="text-xs text-gray-400 font-medium">Available Balance</div>

                <div className="mt-5 grid grid-cols-2 gap-3">
                  <div className="p-3 rounded-xl bg-white/5">
                    <div className="text-[10px] font-bold uppercase tracking-wider text-green-400 mb-1">Credited</div>
                    <div className="text-lg font-extrabold">
                      {walletLoading ? "—" : <span className="flex items-center gap-0.5"><CoinIcon size={15} />{totalCredited.toLocaleString("en-IN")}</span>}
                    </div>
                  </div>
                  <div className="p-3 rounded-xl bg-white/5">
                    <div className="text-[10px] font-bold uppercase tracking-wider text-red-400 mb-1">Debited</div>
                    <div className="text-lg font-extrabold">
                      {walletLoading ? "—" : <span className="flex items-center gap-0.5"><CoinIcon size={15} />{totalDebited.toLocaleString("en-IN")}</span>}
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