import { useState, useEffect, useCallback } from "react";
import { useSelector } from "react-redux";
import api from "../../lib/api";
import {
  Coins, CreditCard, Receipt, ShieldCheck, CalendarDays,
  Download, ArrowDownLeft, ArrowUpRight, RefreshCw,
  CheckCircle2, XCircle, Clock, Loader2, AlertCircle,
  ChevronLeft, ChevronRight, TrendingDown, TrendingUp,
  Wallet, Sparkles, X
} from "lucide-react";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const fmt = (n) => Number(n || 0).toLocaleString("en-IN");
const fmtDate = (d) => d ? new Date(d).toLocaleString("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";
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

const VALID_CURRENCIES = ["INR", "USD", "EUR", "GBP", "AED"];
const fmtCurrency = (n, c) => {
  const cur = VALID_CURRENCIES.includes((c || "").toUpperCase()) ? c.toUpperCase() : "INR";
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: cur, maximumFractionDigits: 0 }).format(n || 0);
};

// ─── Sub-components ───────────────────────────────────────────────────────────

const StatusBadge = ({ status }) => {
  if (status === "SUCCESS") return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-green-600 dark:text-green-400"><CheckCircle2 className="w-3.5 h-3.5" />SUCCESS</span>;
  if (status === "FAILED") return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-red-600 dark:text-red-400"><XCircle className="w-3.5 h-3.5" />FAILED</span>;
  return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-600 dark:text-amber-400"><Clock className="w-3.5 h-3.5" />PENDING</span>;
};

const DirectionBadge = ({ direction }) => (
  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold ${direction === "credit" ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400" : "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"}`}>
    {direction === "credit" ? <ArrowDownLeft className="w-3 h-3" /> : <ArrowUpRight className="w-3 h-3" />}
    {direction === "credit" ? "Credit" : "Debit"}
  </span>
);

// ─── Recharge Modal ───────────────────────────────────────────────────────────

const PACKAGES = [
  { id: "1k",  coins: 1000,  price: 999,   label: "Starter",  popular: false },
  { id: "5k",  coins: 5000,  price: 4499,  label: "Growth",   popular: true  },
  { id: "10k", coins: 10000, price: 8499,  label: "Pro",      popular: false },
  { id: "50k", coins: 50000, price: 39999, label: "Business", popular: false },
];

const RechargeModal = ({ onClose, onSuccess }) => {
  const [step, setStep]         = useState(1); // 1=select, 2=payment, 3=success
  const [packageId, setPackageId] = useState("5k");
  const [method, setMethod]     = useState("upi");
  const [coupon, setCoupon]     = useState("");
  const [couponApplied, setCouponApplied] = useState(false);
  const [billing, setBilling]   = useState({ name: "", address: "", city: "", zip: "" });
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState("");

  const pkg = PACKAGES.find(p => p.id === packageId);

  const handlePayment = async () => {
    if (!billing.name.trim()) { setError("Please enter your full name."); return; }
    setLoading(true);
    setError("");
    try {
      await api.post("/wallet/recharge", {
        coins: pkg.coins,
        amount: pkg.price,
        payment_method: method,
        coupon_code: coupon || undefined,
        billing_details: billing,
      });
      setStep(3);
      onSuccess?.();
    } catch (err) {
      setError(err?.response?.data?.message || "Payment failed. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="w-full max-w-2xl rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl overflow-hidden">

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-yellow-400 to-orange-500 flex items-center justify-center shadow-md">
              <Coins className="w-5 h-5 text-white" />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900 dark:text-white">Recharge Coins</h2>
              <p className="text-xs text-gray-500 dark:text-gray-400">Step {step} of 2 — {step === 1 ? "Select Package" : step === 2 ? "Payment" : "Done"}</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
            <X className="w-4 h-4 text-gray-500" />
          </button>
        </div>

        {/* Step indicator */}
        {step < 3 && (
          <div className="flex gap-0 px-6 pt-4">
            {[1, 2].map(s => (
              <div key={s} className={`h-1 flex-1 rounded-full mx-0.5 transition-all ${s <= step ? "bg-gradient-to-r from-orange-500 to-pink-600" : "bg-gray-100 dark:bg-gray-800"}`} />
            ))}
          </div>
        )}

        <div className="p-6">
          {error && (
            <div className="mb-4 flex items-center gap-2 p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />{error}
            </div>
          )}

          {/* Step 1: Package Selection */}
          {step === 1 && (
            <div className="space-y-5">
              <div>
                <p className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-3">Choose a Coin Package</p>
                <div className="grid grid-cols-2 gap-3">
                  {PACKAGES.map(p => (
                    <button key={p.id} onClick={() => setPackageId(p.id)}
                      className={`relative p-4 rounded-2xl border-2 text-left transition-all ${packageId === p.id ? "border-orange-500 bg-orange-50 dark:bg-orange-900/20" : "border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600"}`}>
                      {p.popular && <span className="absolute -top-2 right-3 text-[10px] font-black px-2 py-0.5 rounded-full bg-gradient-to-r from-orange-500 to-pink-600 text-white">POPULAR</span>}
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-bold text-gray-500 uppercase tracking-wide">{p.label}</span>
                        <Coins className="w-4 h-4 text-yellow-500" />
                      </div>
                      <div className="text-xl font-black text-gray-900 dark:text-white">{fmt(p.coins)} <span className="text-sm font-semibold text-gray-500">coins</span></div>
                      <div className="text-base font-bold text-orange-600 dark:text-orange-400 mt-1">₹{fmt(p.price)}</div>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <p className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Coupon Code</p>
                <div className="flex gap-2">
                  <input value={coupon} onChange={e => setCoupon(e.target.value)} placeholder="Enter code"
                    className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-orange-500/20" />
                  <button onClick={() => coupon && setCouponApplied(true)}
                    className="px-4 py-2.5 rounded-xl bg-gray-900 dark:bg-white text-white dark:text-black text-sm font-bold hover:opacity-80 transition-opacity">
                    Apply
                  </button>
                </div>
                {couponApplied && <p className="text-xs text-green-600 dark:text-green-400 mt-1.5 font-semibold">✓ Coupon applied!</p>}
              </div>

              <button onClick={() => setStep(2)} className="w-full py-3 rounded-2xl bg-gradient-to-r from-orange-500 via-pink-600 to-purple-600 text-white font-bold text-sm hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20">
                Continue to Payment →
              </button>
            </div>
          )}

          {/* Step 2: Payment */}
          {step === 2 && (
            <div className="space-y-5">
              {/* Selected package recap */}
              <div className="flex items-center justify-between p-4 rounded-2xl bg-gray-50 dark:bg-gray-800">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-yellow-400 to-orange-500 flex items-center justify-center">
                    <Coins className="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-gray-900 dark:text-white">{fmt(pkg?.coins)} Coins</div>
                    <div className="text-xs text-gray-500">{pkg?.label} Package</div>
                  </div>
                </div>
                <div className="text-lg font-black text-orange-600 dark:text-orange-400">₹{fmt(pkg?.price)}</div>
              </div>

              <div>
                <p className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Payment Method</p>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { id: "upi", label: "UPI", icon: "🔷" },
                    { id: "card", label: "Card", icon: "💳" },
                    { id: "netbank", label: "Net Banking", icon: "🏦" },
                    { id: "wallet", label: "Wallet", icon: "👜" },
                  ].map(m => (
                    <button key={m.id} onClick={() => setMethod(m.id)}
                      className={`p-3 rounded-xl border text-sm font-semibold flex items-center gap-2 transition-all ${method === m.id ? "border-orange-500 bg-orange-50 dark:bg-orange-900/20 text-orange-700 dark:text-orange-300" : "border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"}`}>
                      <span>{m.icon}</span> {m.label}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <p className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Billing Details</p>
                <div className="space-y-2">
                  {[
                    { key: "name", placeholder: "Full Name *" },
                    { key: "address", placeholder: "Street Address" },
                    { key: "city", placeholder: "City" },
                    { key: "zip", placeholder: "ZIP / Pincode" },
                  ].map(f => (
                    <input key={f.key} value={billing[f.key]} onChange={e => setBilling({ ...billing, [f.key]: e.target.value })} placeholder={f.placeholder}
                      className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-orange-500/20 text-gray-800 dark:text-gray-200" />
                  ))}
                </div>
              </div>

              <div className="flex gap-3">
                <button onClick={() => setStep(1)} className="px-5 py-3 rounded-2xl border border-gray-200 dark:border-gray-700 text-sm font-bold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-gray-700 dark:text-gray-200">
                  ← Back
                </button>
                <button onClick={handlePayment} disabled={loading}
                  className="flex-1 py-3 rounded-2xl bg-gradient-to-r from-orange-500 via-pink-600 to-purple-600 text-white font-bold text-sm hover:opacity-90 disabled:opacity-60 transition-all shadow-lg shadow-pink-500/20 flex items-center justify-center gap-2">
                  {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                  {loading ? "Processing…" : `Pay ₹${fmt(pkg?.price)} Securely 🔒`}
                </button>
              </div>
            </div>
          )}

          {/* Step 3: Success */}
          {step === 3 && (
            <div className="py-6 flex flex-col items-center gap-4 text-center">
              <div className="w-16 h-16 rounded-2xl bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
                <CheckCircle2 className="w-9 h-9 text-green-600 dark:text-green-400" />
              </div>
              <div>
                <h3 className="text-xl font-black text-gray-900 dark:text-white mb-1">Payment Successful!</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">{fmt(pkg?.coins)} coins have been credited to your wallet.</p>
              </div>
              <button onClick={onClose} className="px-8 py-3 rounded-2xl bg-gray-900 dark:bg-white text-white dark:text-black font-bold text-sm hover:opacity-90 transition-opacity">
                Done
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// ─── Main Component ───────────────────────────────────────────────────────────

const LIMIT = 8;

export default function CoinsBilling() {
  const { userObject } = useSelector(s => s.auth);
  const userId = userObject?._id;

  // Wallet
  const [wallet, setWallet]         = useState(null);
  const [walletLoading, setWalletLoading] = useState(true);

  // Transaction history
  const [transactions, setTransactions] = useState([]);
  const [txTotal, setTxTotal]           = useState(0);
  const [txPage, setTxPage]             = useState(1);
  const [txLoading, setTxLoading]       = useState(false);
  const [txError, setTxError]           = useState("");

  // Filters
  const [typeFilter, setTypeFilter]     = useState("");
  const [dirFilter, setDirFilter]       = useState("");
  const [startDate, setStartDate]       = useState("");
  const [endDate, setEndDate]           = useState("");
  const [showFilters, setShowFilters]   = useState(false);

  // Recharge modal
  const [showRecharge, setShowRecharge] = useState(false);

  const totalPages = Math.ceil(txTotal / LIMIT);

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
      const params = { page: txPage, limit: LIMIT };
      if (typeFilter) params.type = typeFilter;
      if (dirFilter)  params.direction = dirFilter;
      if (startDate)  params.startDate = startDate;
      if (endDate)    params.endDate   = endDate;
      const res = await api.get(`/wallet/vendor/${userId}/history`, { params });
      setTransactions(res.data?.transactions || []);
      setTxTotal(res.data?.total || 0);
    } catch (e) {
      setTxError(e?.response?.data?.message || "Failed to load transactions");
    } finally { setTxLoading(false); }
  }, [userId, txPage, typeFilter, dirFilter, startDate, endDate]);

  useEffect(() => { fetchWallet(); }, [fetchWallet]);
  useEffect(() => { fetchHistory(); }, [fetchHistory]);

  const handleApplyFilters = () => { setTxPage(1); fetchHistory(); };
  const handleClearFilters = () => { setTypeFilter(""); setDirFilter(""); setStartDate(""); setEndDate(""); setTxPage(1); };

  // Pagination page numbers
  const getPageNums = () => {
    const windowSize = Math.min(5, totalPages);
    let start = Math.max(1, txPage - Math.floor(windowSize / 2));
    let end = start + windowSize - 1;
    if (end > totalPages) { end = totalPages; start = Math.max(1, end - windowSize + 1); }
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  };

  // Derived coin stats from wallet
  const balance   = wallet?.balance   ?? 0;
  const currency  = wallet?.currency  ?? "INR";

  // compute totals from current tx page
  const credited = transactions.filter(t => t.direction === "credit").reduce((s, t) => s + Number(t.amount || 0), 0);
  const debited  = transactions.filter(t => t.direction === "debit").reduce((s,  t) => s + Number(t.amount || 0), 0);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">

        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
          <div>
            <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-1">
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
                Coins & Billing
              </span>
            </h1>
            <p className="text-gray-500 dark:text-gray-400 text-sm">Manage your wallet balance, recharge coins, and view transaction history.</p>
          </div>
          <div className="flex items-center gap-3">
            <button onClick={() => { fetchWallet(); fetchHistory(); }} className="p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
              <RefreshCw className="w-4 h-4 text-gray-500" />
            </button>
            <button onClick={() => setShowRecharge(true)}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-orange-500 via-pink-600 to-purple-600 text-white font-bold text-sm shadow-lg shadow-pink-500/20 hover:opacity-90 hover:-translate-y-0.5 transition-all">
              <Sparkles className="w-4 h-4" /> Recharge Coins
            </button>
          </div>
        </div>

        {/* Wallet Overview */}
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
                  : <div className="text-4xl font-black tracking-tight">{fmtCurrency(balance, currency)}</div>
                }
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 pt-4 border-t border-white/10">
                {[
                  { label: "Credited (this page)", value: `+₹${fmt(credited)}`, color: "text-green-400", icon: TrendingUp },
                  { label: "Debited (this page)",  value: `-₹${fmt(debited)}`,  color: "text-red-400",   icon: TrendingDown },
                  { label: "Transactions",          value: fmt(txTotal),          color: "text-sky-400",   icon: Receipt },
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
            <button onClick={() => setShowRecharge(true)}
              className="w-full p-4 rounded-2xl bg-gradient-to-r from-orange-500 to-pink-600 text-white font-bold text-sm flex items-center justify-between hover:opacity-90 transition-opacity shadow-md shadow-pink-500/20">
              <span className="flex items-center gap-2"><Coins className="w-4 h-4" /> Buy Coins</span>
              <span>→</span>
            </button>
            {[
              { label: "Download Receipt", icon: Download },
              { label: "View Pricing Plans", icon: Sparkles },
            ].map((a, i) => (
              <button key={i} className="w-full p-3 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 text-left text-sm font-semibold text-gray-700 dark:text-gray-200 transition-colors flex items-center justify-between">
                <span className="flex items-center gap-2"><a.icon className="w-4 h-4 text-gray-400" />{a.label}</span>
                <span className="text-gray-400">→</span>
              </button>
            ))}

            {/* Mini spending bar */}
            {!walletLoading && txTotal > 0 && (
              <div className="mt-auto pt-4 border-t border-gray-100 dark:border-gray-800">
                <div className="flex justify-between text-xs text-gray-500 mb-2">
                  <span>Debit ratio</span>
                  <span className="font-bold">{credited + debited > 0 ? Math.round((debited / (credited + debited)) * 100) : 0}%</span>
                </div>
                <div className="h-2 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden">
                  <div className="h-full rounded-full bg-gradient-to-r from-orange-500 to-pink-600"
                    style={{ width: `${credited + debited > 0 ? Math.round((debited / (credited + debited)) * 100) : 0}%` }} />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Transaction History */}
        <div className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

          {/* Table header */}
          <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100 dark:border-gray-800">
            <div>
              <h2 className="text-base font-bold text-gray-900 dark:text-white">Transaction History</h2>
              <p className="text-xs text-gray-400 mt-0.5">{fmt(txTotal)} total records</p>
            </div>
            <button onClick={() => setShowFilters(f => !f)}
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
                  {transactions.map(tx => (
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
                        <span className={`text-sm font-bold ${tx.direction === "credit" ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`}>
                          {tx.direction === "credit" ? "+" : "−"}₹{fmt(tx.amount)}
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

      {/* Recharge Modal */}
      {showRecharge && (
        <RechargeModal
          onClose={() => setShowRecharge(false)}
          onSuccess={() => { fetchWallet(); fetchHistory(); }}
        />
      )}
    </div>
  );
}