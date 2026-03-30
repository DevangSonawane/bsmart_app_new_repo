import { useState, useEffect, useCallback } from "react";
import { useSelector } from "react-redux";
import api from "../../lib/api";
import {
  Coins, CreditCard, Receipt, ShieldCheck, CalendarDays,
  Download, ArrowDownLeft, ArrowUpRight, RefreshCw,
  CheckCircle2, XCircle, Clock, Loader2, AlertCircle,
  TrendingDown, TrendingUp,
  Wallet, Sparkles,
  ChevronLeft, ChevronRight, Star, Zap, Crown, Package,
  Tag, BadgeCheck, ChevronDown, ChevronUp
} from "lucide-react";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const fmt = (n) => Number(n || 0).toLocaleString("en-IN");
const fmtDate = (d) =>
  d
    ? new Date(d).toLocaleString("en-IN", {
        day: "2-digit", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit",
      })
    : "—";
const timeAgo = (d) => {
  if (!d) return "";
  const diff = Date.now() - new Date(d).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
};

// ─── Coin Icon ─────────────────────────────────────────────────────────────────
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

// ─── Status / Direction Badges ────────────────────────────────────────────────
const StatusBadge = ({ status }) => {
  if (status === "SUCCESS")
    return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-green-600 dark:text-green-400"><CheckCircle2 className="w-3.5 h-3.5" />SUCCESS</span>;
  if (status === "FAILED")
    return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-red-600 dark:text-red-400"><XCircle className="w-3.5 h-3.5" />FAILED</span>;
  return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-600 dark:text-amber-400"><Clock className="w-3.5 h-3.5" />PENDING</span>;
};

const DirectionBadge = ({ direction }) => (
  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold ${direction === "credit" ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400" : "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"}`}>
    {direction === "credit" ? <ArrowDownLeft className="w-3 h-3" /> : <ArrowUpRight className="w-3 h-3" />}
    {direction === "credit" ? "Credit" : "Debit"}
  </span>
);

// ─── Tier icon/colour helpers ──────────────────────────────────────────────────
const TIER_META = {
  basic:      { icon: Package, gradient: "from-slate-400 to-slate-600",   badge: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300" },
  starter:    { icon: Zap,     gradient: "from-blue-400 to-cyan-500",      badge: "bg-blue-100  text-blue-700  dark:bg-blue-900/40  dark:text-blue-300"  },
  growth:     { icon: Star,    gradient: "from-orange-400 to-amber-500",   badge: "bg-orange-100 text-orange-700 dark:bg-orange-900/40 dark:text-orange-300" },
  pro:        { icon: Crown,   gradient: "from-pink-500 to-purple-600",    badge: "bg-pink-100  text-pink-700  dark:bg-pink-900/40  dark:text-pink-300"  },
  business:   { icon: Crown,   gradient: "from-yellow-400 to-orange-500",  badge: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300" },
  enterprise: { icon: Crown,   gradient: "from-purple-500 to-indigo-600",  badge: "bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300" },
};
const getTierMeta = (tier = "") =>
  TIER_META[tier.toLowerCase()] || TIER_META.basic;

// ─── Purchase Success Popup ───────────────────────────────────────────────────
const PurchaseSuccessPopup = ({ pkg, onClose }) => {
  const meta = getTierMeta(pkg.tier);
  const TierIcon = meta.icon;

  // auto-close after 6s
  useEffect(() => {
    const t = setTimeout(onClose, 6000);
    return () => clearTimeout(t);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="w-full max-w-sm rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl overflow-hidden">
        {/* Confetti-style top bar */}
        <div className="h-1.5 bg-gradient-to-r from-green-400 via-emerald-500 to-teal-500" />
        <div className="p-8 flex flex-col items-center gap-5 text-center">
          {/* Animated checkmark */}
          <div className="relative">
            <div className="w-24 h-24 rounded-full bg-gradient-to-br from-green-100 to-emerald-100 dark:from-green-900/40 dark:to-emerald-900/40 flex items-center justify-center">
              <BadgeCheck className="w-12 h-12 text-green-500 dark:text-green-400" />
            </div>
            <div className={`absolute -bottom-1 -right-1 w-9 h-9 rounded-full bg-gradient-to-br ${meta.gradient} flex items-center justify-center shadow-lg`}>
              <TierIcon className="w-4 h-4 text-white" />
            </div>
          </div>

          <div className="space-y-1.5">
            <h3 className="text-2xl font-black text-gray-900 dark:text-white">Purchase Successful! 🎉</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 leading-relaxed">
              Your <span className="font-bold text-orange-500">{pkg.name}</span> package is now active.
              {pkg.coins_granted > 0 && (
                <> <span className="font-bold text-yellow-600 dark:text-yellow-400">{fmt(pkg.coins_granted)} coins</span> have been credited to your wallet.</>
              )}
            </p>
          </div>

          {/* Stats row */}
          <div className="w-full grid grid-cols-2 gap-3">
            {pkg.validity_days > 0 && (
              <div className="p-3 rounded-2xl bg-blue-50 dark:bg-blue-900/20 text-center">
                <CalendarDays className="w-4 h-4 text-blue-500 mx-auto mb-1" />
                <div className="text-lg font-black text-blue-700 dark:text-blue-300">{pkg.validity_days}</div>
                <div className="text-[10px] text-blue-500 font-semibold uppercase tracking-wide">Days Active</div>
              </div>
            )}
            {pkg.ads_allowed_max > 0 && (
              <div className="p-3 rounded-2xl bg-purple-50 dark:bg-purple-900/20 text-center">
                <Receipt className="w-4 h-4 text-purple-500 mx-auto mb-1" />
                <div className="text-lg font-black text-purple-700 dark:text-purple-300">{pkg.ads_allowed_max}</div>
                <div className="text-[10px] text-purple-500 font-semibold uppercase tracking-wide">Ads Allowed</div>
              </div>
            )}
          </div>

          <button
            onClick={onClose}
            className="w-full py-3 rounded-2xl bg-gradient-to-r from-green-500 to-emerald-600 text-white font-bold text-sm hover:opacity-90 transition-opacity shadow-lg shadow-green-500/20"
          >
            Awesome, let's go! →
          </button>
          <p className="text-[10px] text-gray-400">This popup will close automatically</p>
        </div>
      </div>
    </div>
  );
};

// ─── Buy Confirm Modal ────────────────────────────────────────────────────────
const BuyConfirmModal = ({ pkg, onClose, onSuccess }) => {
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState("");
  const meta = getTierMeta(pkg.tier);
  const TierIcon = meta.icon;

  const handleBuy = async () => {
    setLoading(true);
    setError("");
    try {
      await api.post(`/vendor-packages/${pkg._id}/buy`);
      onClose();        // close this confirm modal first
      onSuccess?.(pkg); // parent shows the success popup + refreshes active pkg
    } catch (err) {
      setError(err?.response?.data?.message || "Purchase failed. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
      onClick={e => e.target === e.currentTarget && onClose()}
    >
      <div className="w-full max-w-md rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl overflow-hidden">
        {/* ── Confirm state ── */}
        <div className="p-6 space-y-5">
            {/* Header */}
            <div className="flex items-center gap-3">
              <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${meta.gradient} flex items-center justify-center shadow-md`}>
                <TierIcon className="w-5 h-5 text-white" />
              </div>
              <div>
                <h2 className="text-base font-bold text-gray-900 dark:text-white">Confirm Purchase</h2>
                <p className="text-xs text-gray-500 dark:text-gray-400">Review and confirm your package</p>
              </div>
            </div>

            {/* Package recap */}
            <div className="rounded-2xl border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50 p-4 space-y-3">
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-lg font-black text-gray-900 dark:text-white">{pkg.name}</div>
                  {pkg.description && <div className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{pkg.description}</div>}
                </div>
                <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${meta.badge}`}>
                  {pkg.tier?.toUpperCase()}
                </span>
              </div>

              <div className="grid grid-cols-2 gap-2 pt-2 border-t border-gray-100 dark:border-gray-700">
                {pkg.coins_granted > 0 && (
                  <div className="flex items-center gap-1.5 text-sm">
                    <CoinIcon size={14} />
                    <span className="font-bold text-gray-800 dark:text-gray-200">{fmt(pkg.coins_granted)}</span>
                    <span className="text-gray-500 text-xs">coins</span>
                  </div>
                )}
                {pkg.validity_days > 0 && (
                  <div className="flex items-center gap-1.5 text-sm">
                    <CalendarDays className="w-4 h-4 text-blue-500" />
                    <span className="font-bold text-gray-800 dark:text-gray-200">{pkg.validity_days}</span>
                    <span className="text-gray-500 text-xs">days</span>
                  </div>
                )}
                {pkg.ads_allowed_max > 0 && (
                  <div className="flex items-center gap-1.5 text-sm col-span-2">
                    <Receipt className="w-4 h-4 text-purple-500" />
                    <span className="text-gray-500 text-xs">Ads allowed:</span>
                    <span className="font-bold text-gray-800 dark:text-gray-200">{pkg.ads_allowed_min}–{pkg.ads_allowed_max}</span>
                  </div>
                )}
              </div>

              {/* Price */}
              <div className="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-gray-700">
                <div className="space-y-0.5">
                  {pkg.discount_percent > 0 && (
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-gray-400 line-through">₹{fmt(pkg.base_price)}</span>
                      <span className="text-[10px] font-black px-1.5 py-0.5 rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">
                        -{pkg.discount_percent}%
                      </span>
                    </div>
                  )}
                  <div className="flex items-center gap-1">
                    <span className="text-xs text-gray-500">Total:</span>
                    <span className="text-xl font-black text-orange-500">₹{fmt(pkg.final_price)}</span>
                  </div>
                </div>
                <ShieldCheck className="w-5 h-5 text-green-500" />
              </div>
            </div>

            {error && (
              <div className="flex items-center gap-2 p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
                <AlertCircle className="w-4 h-4 flex-shrink-0" />{error}
              </div>
            )}

            {/* Actions */}
            <div className="flex gap-3">
              <button
                onClick={onClose}
                className="px-5 py-3 rounded-2xl border border-gray-200 dark:border-gray-700 text-sm font-bold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-gray-700 dark:text-gray-200"
              >
                Cancel
              </button>
              <button
                onClick={handleBuy}
                disabled={loading}
                className="flex-1 py-3 rounded-2xl bg-gradient-to-r from-orange-500 via-pink-600 to-purple-600 text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 transition-all shadow-lg shadow-pink-500/20 flex items-center justify-center gap-2"
              >
                {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                {loading ? "Processing…" : `Confirm & Pay ₹${fmt(pkg.final_price)}`}
              </button>
            </div>
          </div>
      </div>
    </div>
  );
};

// ─── Package Card ─────────────────────────────────────────────────────────────
const PackageCard = ({ pkg, onBuy }) => {
  const meta = getTierMeta(pkg.tier);
  const TierIcon = meta.icon;
  const [expanded, setExpanded] = useState(false);
  const isPopular = pkg.tier === "growth" || pkg.tier === "pro";

  return (
    <div className={`relative rounded-3xl border-2 bg-white dark:bg-gray-900 overflow-hidden transition-all hover:-translate-y-1 hover:shadow-xl ${isPopular ? "border-orange-400 dark:border-orange-500 shadow-lg shadow-orange-500/10" : "border-gray-100 dark:border-gray-800"}`}>
      {isPopular && (
        <div className="absolute top-0 left-0 right-0 h-0.5 bg-gradient-to-r from-orange-500 via-pink-500 to-purple-600" />
      )}
      {isPopular && (
        <span className="absolute top-3 right-3 text-[10px] font-black px-2.5 py-1 rounded-full bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-md shadow-orange-500/30 uppercase tracking-wide">
          Popular
        </span>
      )}

      <div className="p-5">
        {/* Tier Icon + Name */}
        <div className="flex items-center gap-3 mb-4">
          <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${meta.gradient} flex items-center justify-center shadow-md`}>
            <TierIcon className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className={`text-[11px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full inline-block ${meta.badge}`}>
              {pkg.tier}
            </div>
            <div className="text-base font-black text-gray-900 dark:text-white mt-0.5">{pkg.name}</div>
          </div>
        </div>

        {/* Price */}
        <div className="mb-4">
          <div className="flex items-end gap-2">
            <span className="text-3xl font-black text-gray-900 dark:text-white">₹{fmt(pkg.final_price)}</span>
            {pkg.discount_percent > 0 && (
              <span className="text-sm text-gray-400 line-through mb-1">₹{fmt(pkg.base_price)}</span>
            )}
          </div>
          <div className="flex items-center gap-2 mt-1 flex-wrap">
            {pkg.validity_days > 0 && (
              <span className="flex items-center gap-1 text-xs text-gray-500 dark:text-gray-400">
                <CalendarDays className="w-3.5 h-3.5" /> {pkg.validity_days} days
              </span>
            )}
            {pkg.discount_percent > 0 && (
              <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">
                Save {pkg.discount_percent}%
              </span>
            )}
            {pkg.coins_granted > 0 && (
              <span className="flex items-center gap-1 text-xs font-bold text-yellow-600 dark:text-yellow-400">
                <CoinIcon size={12} /> {fmt(pkg.coins_granted)} coins
              </span>
            )}
          </div>
        </div>

        {/* Ads allowed */}
        {pkg.ads_allowed_max > 0 && (
          <div className="flex items-center gap-2 mb-3 px-3 py-2 rounded-xl bg-gray-50 dark:bg-gray-800 text-sm">
            <Receipt className="w-4 h-4 text-purple-500 flex-shrink-0" />
            <span className="text-gray-600 dark:text-gray-300">
              <span className="font-bold text-gray-900 dark:text-white">{pkg.ads_allowed_min}–{pkg.ads_allowed_max}</span> ads allowed
            </span>
          </div>
        )}

        {/* Features toggle */}
        {pkg.features?.length > 0 && (
          <div className="mb-4">
            <button
              onClick={() => setExpanded(v => !v)}
              className="flex items-center gap-1 text-xs font-semibold text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition-colors mb-2"
            >
              {expanded ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
              {expanded ? "Hide features" : "View features"}
            </button>
            {expanded && (
              <ul className="space-y-1.5">
                {pkg.features.map((f, i) => (
                  <li key={i} className="flex items-start gap-2 text-xs text-gray-600 dark:text-gray-300">
                    <CheckCircle2 className="w-3.5 h-3.5 text-green-500 flex-shrink-0 mt-0.5" />
                    {f}
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {/* Description */}
        {pkg.description && (
          <p className="text-xs text-gray-400 dark:text-gray-500 mb-4 leading-relaxed">{pkg.description}</p>
        )}

        {/* CTA */}
        <button
          onClick={() => onBuy(pkg)}
          className={`w-full py-3 rounded-2xl text-sm font-bold transition-all hover:opacity-90 hover:-translate-y-0.5 shadow-md ${isPopular ? "bg-gradient-to-r from-orange-500 via-pink-600 to-purple-600 text-white shadow-pink-500/20" : "bg-gray-900 dark:bg-white text-white dark:text-gray-900 shadow-gray-900/10"}`}
        >
          Get {pkg.name} →
        </button>
      </div>
    </div>
  );
};

// ─── Active Package Card ──────────────────────────────────────────────────────
const ActivePackageCard = ({ refreshTrigger }) => {
  const [active, setActive]   = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState("");

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const res = await api.get("/vendor-packages/my/active");
        setActive(res.data?.active_package || res.data?.package || res.data || null);
      } catch (e) {
        if (e?.response?.status === 404) {
          setActive(null); // no active package — not an error
        } else {
          setError(e?.response?.data?.message || "Could not load active package.");
        }
      } finally {
        setLoading(false); 
      }
    };
    load();
  }, [refreshTrigger]);

  if (loading) {
    return (
      <div className="mb-8 rounded-3xl border-2 border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 p-6 animate-pulse">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-gray-800" />
          <div className="flex-1 space-y-2">
            <div className="h-4 w-32 bg-gray-100 dark:bg-gray-800 rounded-lg" />
            <div className="h-3 w-48 bg-gray-100 dark:bg-gray-800 rounded" />
          </div>
          <div className="h-8 w-24 bg-gray-100 dark:bg-gray-800 rounded-xl" />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="mb-8 flex items-center gap-3 p-4 rounded-2xl bg-red-50 dark:bg-red-900/10 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
        <AlertCircle className="w-4 h-4 flex-shrink-0" />{error}
      </div>
    );
  }

  if (!active) {
    return (
      <div className="mb-8 flex items-center gap-4 p-5 rounded-3xl border-2 border-dashed border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/30">
        <div className="w-12 h-12 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center flex-shrink-0">
          <Package className="w-6 h-6 text-gray-400" />
        </div>
        <div>
          <div className="text-sm font-bold text-gray-700 dark:text-gray-300">No Active Package</div>
          <div className="text-xs text-gray-400 mt-0.5">Purchase a package below to get started with advertising.</div>
        </div>
      </div>
    );
  }

  // API shape: { success, active_package: { purchase_id, package: {...}, amount_paid, coins_credited, purchased_at, expires_at, status } }
  const activeData   = active.active_package || active;
  const pkg          = activeData.package || activeData;
  const meta         = getTierMeta(pkg.tier);
  const TierIcon     = meta.icon;
  const name         = pkg.name        || "Active Package";
  const tier         = pkg.tier        || "";
  const validityDays = pkg.validity_days  ?? 0;
  const adsMax       = pkg.ads_allowed_max ?? 0;
  const adsMin       = pkg.ads_allowed_min ?? 0;
  const coinsGranted = activeData.coins_credited ?? pkg.coins_granted ?? 0;
  const amountPaid   = activeData.amount_paid   ?? pkg.final_price    ?? 0;
  const features     = pkg.features || [];
  const expiresAt    = activeData.expires_at   || null;
  const purchasedAt  = activeData.purchased_at || null;
  const status       = activeData.status       || "active";

  const daysLeft = expiresAt
    ? Math.max(0, Math.ceil((new Date(expiresAt) - Date.now()) / 86400000))
    : null;

  return (
    <div className="mb-8 relative overflow-hidden rounded-3xl border-2 border-green-300 dark:border-green-700 bg-white dark:bg-gray-900 shadow-lg shadow-green-500/10">
      {/* Top accent */}
      <div className="h-1 bg-gradient-to-r from-green-400 via-emerald-500 to-teal-500" />

      <div className="p-6">
        <div className="flex flex-col sm:flex-row sm:items-start gap-5">
          {/* Icon + tier */}
          <div className="flex items-center gap-4 flex-shrink-0">
            <div className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${meta.gradient} flex items-center justify-center shadow-lg`}>
              <TierIcon className="w-7 h-7 text-white" />
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <span className={`text-[11px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full ${meta.badge}`}>{tier}</span>
                <span className={`flex items-center gap-1 text-[11px] font-bold px-2 py-0.5 rounded-full ${status === "active" ? "bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400" : "bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-400"}`}>
                  <CheckCircle2 className="w-3 h-3" /> {status.charAt(0).toUpperCase() + status.slice(1)}
                </span>
              </div>
              <div className="text-lg font-black text-gray-900 dark:text-white mt-1">{name}</div>
            </div>
          </div>

          {/* Stats grid */}
          <div className="flex-1 grid grid-cols-2 sm:grid-cols-4 gap-3">
            {/* Days Left — colour-coded */}
            <div className={`p-3 rounded-2xl text-center ${daysLeft !== null && daysLeft <= 3 ? "bg-red-50 dark:bg-red-900/20" : daysLeft !== null && daysLeft <= 7 ? "bg-amber-50 dark:bg-amber-900/20" : "bg-blue-50 dark:bg-blue-900/20"}`}>
              <CalendarDays className={`w-4 h-4 mx-auto mb-1 ${daysLeft !== null && daysLeft <= 3 ? "text-red-500" : daysLeft !== null && daysLeft <= 7 ? "text-amber-500" : "text-blue-500"}`} />
              <div className={`text-base font-black ${daysLeft !== null && daysLeft <= 3 ? "text-red-700 dark:text-red-300" : daysLeft !== null && daysLeft <= 7 ? "text-amber-700 dark:text-amber-300" : "text-blue-700 dark:text-blue-300"}`}>
                {daysLeft !== null ? daysLeft : validityDays}
              </div>
              <div className={`text-[10px] font-semibold uppercase tracking-wide ${daysLeft !== null && daysLeft <= 3 ? "text-red-500" : daysLeft !== null && daysLeft <= 7 ? "text-amber-500" : "text-blue-500"}`}>
                Days Left
              </div>
            </div>

            {/* Ads Allowed */}
            {adsMax > 0 && (
              <div className="p-3 rounded-2xl bg-purple-50 dark:bg-purple-900/20 text-center">
                <Receipt className="w-4 h-4 text-purple-500 mx-auto mb-1" />
                <div className="text-base font-black text-purple-700 dark:text-purple-300">{adsMin}–{adsMax}</div>
                <div className="text-[10px] text-purple-500 font-semibold uppercase tracking-wide">Ads Allowed</div>
              </div>
            )}

            {/* Coins Credited */}
            {coinsGranted > 0 && (
              <div className="p-3 rounded-2xl bg-yellow-50 dark:bg-yellow-900/20 text-center">
                <CoinIcon size={16} className="mx-auto mb-1" />
                <div className="text-base font-black text-yellow-700 dark:text-yellow-400">{fmt(coinsGranted)}</div>
                <div className="text-[10px] text-yellow-600 font-semibold uppercase tracking-wide">Coins Credited</div>
              </div>
            )}

            {/* Amount Paid */}
            {amountPaid > 0 && (
              <div className="p-3 rounded-2xl bg-gray-50 dark:bg-gray-800 text-center">
                <ShieldCheck className="w-4 h-4 text-gray-400 mx-auto mb-1" />
                <div className="text-base font-black text-gray-700 dark:text-gray-300">₹{fmt(amountPaid)}</div>
                <div className="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">Paid</div>
              </div>
            )}
          </div>
        </div>

        {/* Dates + purchase ID row */}
        <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 text-xs text-gray-500 dark:text-gray-400">
          {purchasedAt && (
            <span className="flex items-center gap-1.5">
              <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />
              <span>Activated:</span>
              <span className="font-semibold text-gray-700 dark:text-gray-300">
                {new Date(purchasedAt).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}
              </span>
            </span>
          )}
          {expiresAt && (
            <span className="flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5 text-orange-400" />
              <span>Expires:</span>
              <span className="font-semibold text-gray-700 dark:text-gray-300">
                {new Date(expiresAt).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}
              </span>
            </span>
          )}
          {activeData.purchase_id && (
            <span className="flex items-center gap-1.5 sm:ml-auto">
              <Receipt className="w-3.5 h-3.5 text-gray-400" />
              <span>Purchase ID:</span>
              <span className="font-mono text-[11px] text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-lg">
                {activeData.purchase_id}
              </span>
            </span>
          )}
        </div>

        {/* Features */}
        {features.length > 0 && (
          <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-800">
            <p className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-2">Included Features</p>
            <div className="flex flex-wrap gap-2">
              {features.map((f, i) => (
                <span key={i} className="flex items-center gap-1 text-xs text-gray-600 dark:text-gray-300 bg-gray-50 dark:bg-gray-800 px-2.5 py-1 rounded-full border border-gray-100 dark:border-gray-700">
                  <CheckCircle2 className="w-3 h-3 text-green-500 flex-shrink-0" /> {f}
                </span>
              ))}
            </div>
          </div>
        )}

        {/* Validity progress bar */}
        {daysLeft !== null && validityDays > 0 && (
          <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-800">
            <div className="flex justify-between text-xs text-gray-500 mb-1.5">
              <span>Validity period</span>
              <span className={`font-bold ${daysLeft <= 3 ? "text-red-500" : daysLeft <= 7 ? "text-amber-500" : "text-green-600 dark:text-green-400"}`}>
                {daysLeft} / {validityDays} days remaining
              </span>
            </div>
            <div className="h-2 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden">
              <div
                className={`h-full rounded-full transition-all ${daysLeft <= 3 ? "bg-red-500" : daysLeft <= 7 ? "bg-amber-500" : "bg-gradient-to-r from-green-400 to-emerald-500"}`}
                style={{ width: `${Math.min(100, Math.round((daysLeft / validityDays) * 100))}%` }}
              />
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

// ─── Packages Section ─────────────────────────────────────────────────────────
const PackagesSection = ({ onBuySuccess }) => {
  const [packages, setPackages]       = useState([]);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState("");
  const [buyTarget, setBuyTarget]     = useState(null);
  const [successPkg, setSuccessPkg]   = useState(null); // drives success popup
  const [activeRefresh, setActiveRefresh] = useState(0); // bump to re-fetch active pkg

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const res = await api.get("/vendor-packages");
        setPackages(res.data?.packages || res.data || []);
      } catch (e) {
        setError(e?.response?.data?.message || "Failed to load packages.");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  // Handler called by BuyConfirmModal on success
  const handleBuySuccess = (pkg) => {
    setSuccessPkg(pkg);           // show success popup
    setActiveRefresh(n => n + 1); // refresh active package card
    onBuySuccess?.();             // refresh wallet balance in parent
  };

  return (
    <div className="mb-8">
      {/* ── Active package banner ── */}
      <div className="mb-6">
        <p className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-3">Your Current Package</p>
        <ActivePackageCard refreshTrigger={activeRefresh} />
      </div>

      {/* Section header */}
      <div className="flex items-center justify-between mb-5">
        <div>
          <h2 className="text-xl font-extrabold text-gray-900 dark:text-white">
            Choose a Package
          </h2>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
            Select the plan that best fits your advertising needs
          </p>
        </div>
        <span className="flex items-center gap-1.5 text-xs font-semibold px-3 py-1.5 rounded-full border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400">
          <ShieldCheck className="w-3.5 h-3.5" /> Secure Checkout
        </span>
      </div>

      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="rounded-3xl border-2 border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 p-5 animate-pulse">
              <div className="w-11 h-11 rounded-xl bg-gray-100 dark:bg-gray-800 mb-4" />
              <div className="h-4 w-20 bg-gray-100 dark:bg-gray-800 rounded-lg mb-2" />
              <div className="h-8 w-28 bg-gray-100 dark:bg-gray-800 rounded-xl mb-3" />
              <div className="h-3 w-full bg-gray-100 dark:bg-gray-800 rounded mb-2" />
              <div className="h-3 w-4/5 bg-gray-100 dark:bg-gray-800 rounded mb-4" />
              <div className="h-10 w-full bg-gray-100 dark:bg-gray-800 rounded-2xl" />
            </div>
          ))}
        </div>
      ) : error ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3 text-center rounded-3xl border-2 border-dashed border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/10">
          <AlertCircle className="w-8 h-8 text-red-400" />
          <div>
            <p className="text-sm font-semibold text-red-600 dark:text-red-400">{error}</p>
            <button onClick={() => window.location.reload()} className="text-xs text-red-500 underline mt-1">Try again</button>
          </div>
        </div>
      ) : packages.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3 text-center rounded-3xl border-2 border-dashed border-gray-200 dark:border-gray-700">
          <Package className="w-8 h-8 text-gray-300" />
          <p className="text-sm text-gray-400">No packages available at the moment.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {packages.map((pkg) => (
            <PackageCard key={pkg._id || pkg.tier} pkg={pkg} onBuy={setBuyTarget} />
          ))}
        </div>
      )}

      {/* Coupon row */}
      {!loading && packages.length > 0 && (
        <div className="mt-5 flex items-center gap-3 p-4 rounded-2xl border border-dashed border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/40">
          <Tag className="w-4 h-4 text-gray-400 flex-shrink-0" />
          <input
            type="text"
            placeholder="Have a coupon code? Enter here"
            className="flex-1 bg-transparent text-sm outline-none text-gray-700 dark:text-gray-200 placeholder-gray-400"
          />
          <button className="px-4 py-1.5 rounded-xl bg-gray-900 dark:bg-white text-white dark:text-black text-xs font-bold hover:opacity-80 transition-opacity">
            Apply
          </button>
        </div>
      )}

      {/* Confirm modal */}
      {buyTarget && (
        <BuyConfirmModal
          pkg={buyTarget}
          onClose={() => setBuyTarget(null)}
          onSuccess={handleBuySuccess}
        />
      )}

      {/* Purchase success popup */}
      {successPkg && (
        <PurchaseSuccessPopup
          pkg={successPkg}
          onClose={() => setSuccessPkg(null)}
        />
      )}
    </div>
  );
};

// ─── Main Component ───────────────────────────────────────────────────────────

const LIMIT = 7;

export default function CoinsBilling() {
  const { userObject } = useSelector(s => s.auth);
  const userId = userObject?._id;

  // Wallet
  const [wallet, setWallet]               = useState(null);
  const [walletLoading, setWalletLoading] = useState(true);

  // Transaction history
  const [transactions, setTransactions] = useState([]);
  const [txTotal, setTxTotal]           = useState(0);
  const [txPage, setTxPage]             = useState(1);
  const [txLoading, setTxLoading]       = useState(false);
  const [txError, setTxError]           = useState("");

  // Filters
  const [typeFilter, setTypeFilter]   = useState("");
  const [dirFilter, setDirFilter]     = useState("");
  const [startDate, setStartDate]     = useState("");
  const [endDate, setEndDate]         = useState("");
  const [showFilters, setShowFilters] = useState(false);

  const totalPages = Math.ceil(transactions.length / LIMIT);

  // ── Fetch wallet balance ───────────────────────────────────────────────────
  const fetchWallet = useCallback(async () => {
    setWalletLoading(true);
    try {
      const res = await api.get("/wallet/me");
      setWallet(res.data?.wallet || res.data);
    } catch (e) { console.error(e); }
    finally { setWalletLoading(false); }
  }, []);

  // ── Fetch transaction history ──────────────────────────────────────────────
  const fetchHistory = useCallback(async () => {
    if (!userId) return;
    setTxLoading(true);
    setTxError("");
    try {
      const params = {};
      if (typeFilter) params.type      = typeFilter;
      if (dirFilter)  params.direction = dirFilter;
      if (startDate)  params.startDate = startDate;
      if (endDate)    params.endDate   = endDate;
      const res = await api.get(`/wallet/vendor/${userId}/history`, { params });
      const allTx = res.data?.transactions || [];
      setTransactions(allTx);
      setTxTotal(res.data?.total || allTx.length);
    } catch (e) {
      setTxError(e?.response?.data?.message || "Failed to load transactions");
    } finally { setTxLoading(false); }
  }, [userId, typeFilter, dirFilter, startDate, endDate]);

  useEffect(() => { fetchWallet(); }, [fetchWallet]);
  useEffect(() => { fetchHistory(); }, [fetchHistory]);

  const handleApplyFilters = () => { setTxPage(1); fetchHistory(); setShowFilters(false); };
  const handleClearFilters = () => {
    setTypeFilter(""); setDirFilter(""); setStartDate(""); setEndDate("");
    setTxPage(1); fetchHistory(); setShowFilters(false);
  };

  const getPageNums = () => {
    const windowSize = Math.min(5, totalPages);
    let start = Math.max(1, txPage - Math.floor(windowSize / 2));
    let end   = start + windowSize - 1;
    if (end > totalPages) { end = totalPages; start = Math.max(1, end - windowSize + 1); }
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  };

  // Derived stats
  const balance  = wallet?.balance ?? 0;
  const credited = transactions.filter(t => t.direction === "credit").reduce((s, t) => s + Number(t.amount || 0), 0);
  const debited  = transactions.filter(t => t.direction === "debit").reduce((s, t)  => s + Number(t.amount || 0), 0);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">

        {/* ── Page Header ── */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
          <div>
            <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-1">
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
                Coins & Billing
              </span>
            </h1>
            <p className="text-gray-500 dark:text-gray-400 text-sm">
              Manage your wallet balance, buy packages, and view transaction history.
            </p>
          </div>
          <button
            onClick={() => { fetchWallet(); fetchHistory(); }}
            className="p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors self-start sm:self-auto"
          >
            <RefreshCw className="w-4 h-4 text-gray-500" />
          </button>
        </div>

        {/* ── Wallet Overview ── */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {/* Big wallet card */}
          <div className="lg:col-span-2 rounded-3xl bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white relative overflow-hidden p-6">
            <div className="absolute top-0 right-0 w-72 h-72 bg-yellow-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
            <div className="absolute bottom-0 left-0 w-48 h-48 bg-pink-600/10 rounded-full blur-3xl translate-y-1/2 -translate-x-1/2" />
            <div className="relative z-10">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Wallet className="w-4 h-4 text-yellow-400" />
                  <span className="text-xs font-bold uppercase tracking-wider text-gray-400">Wallet Overview</span>
                </div>
                {walletLoading && <Loader2 className="w-4 h-4 animate-spin text-gray-400" />}
              </div>

              <div className="mb-5">
                <div className="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1">Available Balance</div>
                {walletLoading
                  ? <div className="h-10 w-40 bg-white/10 rounded-xl animate-pulse" />
                  : <div className="text-4xl font-black tracking-tight flex items-center gap-1">
                      <CoinIcon size={32} />
                      {new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(balance || 0)}
                    </div>
                }
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 pt-4 border-t border-white/10">
                {[
                  { label: "Credited (this page)", value: <span className="flex items-center gap-0.5">+<CoinIcon size={14} />{fmt(credited)}</span>, color: "text-green-400", icon: TrendingUp },
                  { label: "Debited (this page)",  value: <span className="flex items-center gap-0.5">-<CoinIcon size={14} />{fmt(debited)}</span>,  color: "text-red-400",   icon: TrendingDown },
                  { label: "Transactions",         value: fmt(txTotal),          color: "text-sky-400",   icon: Receipt },
                ].map((item, i) => (
                  <div key={i} className="p-3 rounded-2xl bg-white/5">
                    <div className="flex items-center gap-1.5 mb-1">
                      <item.icon className={`w-3.5 h-3.5 ${item.color}`} />
                      <span className="text-[10px] font-bold uppercase tracking-wider text-gray-400">{item.label}</span>
                    </div>
                    <div className={`text-lg font-extrabold ${item.color}`}>{item.value}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-6 flex flex-col gap-4">
            <h3 className="text-sm font-bold text-gray-900 dark:text-white uppercase tracking-wider">Quick Actions</h3>
            <a href="#packages"
              className="w-full p-4 rounded-2xl bg-gradient-to-r from-orange-500 to-pink-600 text-white font-bold text-sm flex items-center justify-between hover:opacity-90 transition-opacity shadow-md shadow-pink-500/20 cursor-pointer">
              <span className="flex items-center gap-2"><Coins className="w-4 h-4" /> Buy Package</span>
              <span>→</span>
            </a>
            {[
              { label: "Download Receipt", icon: Download },
              { label: "View Pricing Plans", icon: Sparkles },
            ].map((a, i) => (
              <button key={i} className="w-full p-3 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 text-left text-sm font-semibold text-gray-700 dark:text-gray-200 transition-colors flex items-center justify-between">
                <span className="flex items-center gap-2"><a.icon className="w-4 h-4 text-gray-400" />{a.label}</span>
                <span className="text-gray-400">→</span>
              </button>
            ))}

            {!walletLoading && txTotal > 0 && (
              <div className="mt-auto pt-4 border-t border-gray-100 dark:border-gray-800">
                <div className="flex justify-between text-xs text-gray-500 mb-2">
                  <span>Debit ratio</span>
                  <span className="font-bold">
                    {credited + debited > 0 ? Math.round((debited / (credited + debited)) * 100) : 0}%
                  </span>
                </div>
                <div className="h-2 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-orange-500 to-pink-600"
                    style={{ width: `${credited + debited > 0 ? Math.round((debited / (credited + debited)) * 100) : 0}%` }}
                  />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* ── Packages Section (replaces modal) ── */}
        <div id="packages">
          <PackagesSection onBuySuccess={fetchWallet} />
        </div>

        {/* ── Transaction History ── */}
        <div className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

          {/* Table header */}
          <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100 dark:border-gray-800">
            <div>
              <h2 className="text-base font-bold text-gray-900 dark:text-white">Transaction History</h2>
              <p className="text-xs text-gray-400 mt-0.5">{fmt(txTotal)} total records</p>
            </div>
            <button
              onClick={() => setShowFilters(f => !f)}
              className={`flex items-center gap-2 text-xs font-semibold px-3 py-1.5 rounded-full border transition-colors ${showFilters || typeFilter || dirFilter || startDate || endDate ? "bg-pink-50 dark:bg-pink-900/20 text-pink-600 dark:text-pink-400 border-pink-200 dark:border-pink-800" : "bg-gray-50 dark:bg-gray-800 text-gray-500 border-gray-200 dark:border-gray-700"}`}>
              🔍 Filters {(typeFilter || dirFilter || startDate || endDate) ? "●" : ""}
            </button>
          </div>

          {/* Filters */}
          {showFilters && (
            <div className="px-6 py-4 bg-gray-50 dark:bg-gray-800/50 border-b border-gray-100 dark:border-gray-800">
              <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-1">Type</label>
                  <select value={typeFilter} onChange={e => setTypeFilter(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none">
                    {["", "AD_SPEND", "RECHARGE", "REFUND", "BONUS"].map(t => <option key={t} value={t}>{t || "All Types"}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-1">Direction</label>
                  <select value={dirFilter} onChange={e => setDirFilter(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none">
                    {["", "credit", "debit"].map(d => <option key={d} value={d}>{d || "All"}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-1">From</label>
                  <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-1">To</label>
                  <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-800 dark:text-gray-200 outline-none" />
                </div>
                <div className="flex items-end gap-2">
                  <button onClick={handleApplyFilters} className="flex-1 py-2 rounded-xl bg-gradient-to-r from-pink-600 to-orange-500 text-white text-xs font-bold hover:opacity-90 transition-opacity">Apply</button>
                  <button onClick={handleClearFilters} className="flex-1 py-2 rounded-xl border border-gray-200 dark:border-gray-700 text-xs font-bold text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">Clear</button>
                </div>
              </div>
            </div>
          )}

          {/* Table */}
          {txLoading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 className="w-8 h-8 animate-spin text-pink-500" />
              <span className="text-sm text-gray-400">Loading transactions…</span>
            </div>
          ) : txError ? (
            <div className="flex items-center justify-center py-16 gap-3 text-red-500">
              <AlertCircle className="w-5 h-5" /><span className="text-sm">{txError}</span>
            </div>
          ) : transactions.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
              <Wallet className="w-10 h-10 opacity-30" />
              <p className="text-sm font-medium">No transactions found</p>
              {(typeFilter || dirFilter || startDate || endDate) && (
                <button onClick={handleClearFilters} className="text-xs text-pink-500 underline">Clear filters</button>
              )}
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
                    {["Transaction", "Amount", "Direction", "Status", "Date"].map(h => (
                      <th key={h} className="px-5 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                  {transactions.slice((txPage - 1) * LIMIT, txPage * LIMIT).map(tx => (
                    <tr key={tx._id} className="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-3">
                          <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${tx.direction === "credit" ? "bg-green-100 dark:bg-green-900/30" : "bg-red-100 dark:bg-red-900/30"}`}>
                            {tx.direction === "credit"
                              ? <ArrowDownLeft className="w-4 h-4 text-green-600 dark:text-green-400" />
                              : <ArrowUpRight className="w-4 h-4 text-red-600 dark:text-red-400" />}
                          </div>
                          <div>
                            <div className="text-sm font-semibold text-gray-900 dark:text-white leading-tight">{tx.label || tx.type || "Transaction"}</div>
                            {tx.description && <div className="text-xs text-gray-400 mt-0.5 max-w-[200px] truncate">{tx.description}</div>}
                            {tx.ad?.title && <div className="text-xs text-pink-500 mt-0.5">📢 {tx.ad.title}</div>}
                          </div>
                        </div>
                      </td>
                      <td className="px-5 py-3.5">
                        <span className={`text-sm font-bold flex items-center gap-0.5 ${tx.direction === "credit" ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`}>
                          {tx.direction === "credit" ? "+" : "−"}<CoinIcon size={13} />{fmt(tx.amount)}
                        </span>
                      </td>
                      <td className="px-5 py-3.5"><DirectionBadge direction={tx.direction} /></td>
                      <td className="px-5 py-3.5"><StatusBadge status={tx.status} /></td>
                      <td className="px-5 py-3.5">
                        <div className="text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">{fmtDate(tx.created_at)}</div>
                        <div className="text-[10px] text-gray-400 dark:text-gray-500">{timeAgo(tx.created_at)}</div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between px-6 py-4 border-t border-gray-100 dark:border-gray-800">
              <span className="text-xs text-gray-400">Page {txPage} of {totalPages} · {fmt(txTotal)} records</span>
              <div className="flex items-center gap-1.5">
                <button onClick={() => setTxPage(p => Math.max(1, p - 1))} disabled={txPage === 1}
                  className="p-2 rounded-xl border border-gray-200 dark:border-gray-700 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <ChevronLeft className="w-4 h-4" />
                </button>
                {getPageNums().map(p => (
                  <button key={p} onClick={() => setTxPage(p)}
                    className={`w-8 h-8 rounded-xl text-xs font-bold transition-colors ${txPage === p ? "bg-gradient-to-r from-pink-600 to-orange-500 text-white shadow-sm" : "border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"}`}>
                    {p}
                  </button>
                ))}
                <button onClick={() => setTxPage(p => Math.min(totalPages, p + 1))} disabled={txPage === totalPages}
                  className="p-2 rounded-xl border border-gray-200 dark:border-gray-700 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
        </div>

      </div>
    </div>
  );
}