import React, { useState, useEffect, useCallback } from 'react';
import {
  ArrowLeft, ChevronDown, SlidersHorizontal, ArrowUpRight, ShoppingCart,
  CheckCircle2, User, Mail, Phone, Building2, Globe, Coins,
  TrendingUp, TrendingDown, Heart, Eye, MessageCircle, Bookmark,
  RefreshCw, Loader2, AlertCircle, Sparkles, Wallet
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';

// ─── Helpers ────────────────────────────────────────────────────────────────

const BASE_URL = 'https://api.bebsmart.in';

const TX_META = {
  AD_LIKE_REWARD:           { label: 'Ad Like Reward',         icon: Heart,         color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  AD_LIKE_REWARD_REVERSAL:  { label: 'Like Reversed',          icon: Heart,         color: 'text-rose-400',    bg: 'bg-rose-400/10',    dir: 'debit'  },
  AD_VIEW_REWARD:           { label: 'Ad View Reward',         icon: Eye,           color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  AD_VIEW_DEDUCTION:        { label: 'Ad View Spent',          icon: Eye,           color: 'text-rose-400',    bg: 'bg-rose-400/10',    dir: 'debit'  },
  AD_COMMENT_REWARD:        { label: 'Comment Reward',         icon: MessageCircle, color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  AD_SAVE_REWARD:           { label: 'Save Reward',            icon: Bookmark,      color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  AD_LIKE_DEDUCTION:        { label: 'Like Budget Spent',      icon: Heart,         color: 'text-rose-400',    bg: 'bg-rose-400/10',    dir: 'debit'  },
  AD_BUDGET_DEDUCTION:      { label: 'Ad Budget Deducted',     icon: TrendingDown,  color: 'text-rose-400',    bg: 'bg-rose-400/10',    dir: 'debit'  },
  AD_LIKE_BUDGET_REFUND:    { label: 'Like Budget Refund',     icon: TrendingUp,    color: 'text-sky-400',     bg: 'bg-sky-400/10',     dir: 'credit' },
  VENDOR_REGISTRATION_CREDIT:{ label: 'Registration Bonus',   icon: Sparkles,      color: 'text-amber-400',   bg: 'bg-amber-400/10',   dir: 'credit' },
  VENDOR_RECHARGE:          { label: 'Wallet Recharge',        icon: TrendingUp,    color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  ADMIN_ADJUSTMENT:         { label: 'Admin Adjustment',       icon: SlidersHorizontal, color: 'text-violet-400', bg: 'bg-violet-400/10', dir: 'credit' },
  REEL_VIEW_REWARD:         { label: 'Reel View Reward',       icon: Eye,           color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  AD_REPLY_REWARD:          { label: 'Reply Reward',           icon: MessageCircle, color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  VENDOR_PROFILE_VIEW_REWARD:{ label: 'Profile View Reward',  icon: Eye,           color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  LIKE:                     { label: 'Like Reward',            icon: Heart,         color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  COMMENT:                  { label: 'Comment Reward',         icon: MessageCircle, color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
  SAVE:                     { label: 'Save Reward',            icon: Bookmark,      color: 'text-emerald-400', bg: 'bg-emerald-400/10', dir: 'credit' },
};

const getTxMeta = (type) =>
  TX_META[type] || { label: type, icon: Coins, color: 'text-gray-400', bg: 'bg-gray-400/10', dir: 'credit' };

const formatDate = (iso) => {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) +
    ' · ' + d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
};

const formatCoins = (n) => {
  if (n === undefined || n === null) return '0';
  const abs = Math.abs(Number(n));
  if (abs >= 1_000_000) return (abs / 1_000_000).toFixed(1) + 'M';
  if (abs >= 1_000) return (abs / 1_000).toFixed(1) + 'K';
  return Math.floor(abs).toString();
};

// ─── Sub-components ──────────────────────────────────────────────────────────

const AccordionItem = ({ id, title, openSection, setOpenSection, children, badge }) => {
  const open = openSection === id;
  return (
    <div className={`rounded-2xl border transition-all duration-200 ${open ? 'border-gray-200 bg-white dark:border-white/10 dark:bg-[#141414]' : 'border-gray-200 bg-white dark:border-white/[0.06] dark:bg-[#0f0f0f]'}`}>
      <button
        onClick={() => setOpenSection(open ? '' : id)}
        className="w-full px-5 py-4 flex items-center justify-between"
      >
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-gray-900 dark:text-white tracking-tight">{title}</span>
          {badge && (
            <span className="px-1.5 py-0.5 text-[10px] font-bold rounded-full bg-orange-100 dark:bg-orange-500/20 text-orange-500 dark:text-orange-400 border border-orange-200 dark:border-orange-500/30">
              {badge}
            </span>
          )}
        </div>
        <ChevronDown
          size={16}
          className={`transition-transform duration-300 text-gray-400 dark:text-white/40 ${open ? 'rotate-180' : ''}`}
        />
      </button>
      {open && (
        <div className="px-5 pb-5 border-t border-gray-100 dark:border-white/[0.06]">
          {children}
        </div>
      )}
    </div>
  );
};

const StatPill = ({ label, value, positive }) => (
  <div className="flex flex-col gap-0.5">
    <span className="text-[10px] font-medium text-white/60 uppercase tracking-widest">{label}</span>
    <span className={`text-lg font-bold ${positive ? 'text-emerald-400' : positive === false ? 'text-rose-400' : 'text-white'}`}>
      {value}
    </span>
  </div>
);

const TxSkeleton = () => (
  <div className="space-y-3 min-h-[120px]">
    {[1, 2, 3].map(i => (
      <div key={i} className="flex items-center gap-3 p-4 rounded-xl bg-gray-100 dark:bg-white/[0.03] animate-pulse">
        <div className="w-9 h-9 rounded-xl bg-gray-200 dark:bg-white/10 shrink-0" />
        <div className="flex-1 space-y-2">
          <div className="h-3 bg-gray-200 dark:bg-white/10 rounded w-2/3" />
          <div className="h-2.5 bg-gray-100 dark:bg-white/[0.06] rounded w-1/3" />
        </div>
        <div className="h-4 w-14 bg-gray-200 dark:bg-white/10 rounded" />
      </div>
    ))}
  </div>
);

// ─── Main Component ───────────────────────────────────────────────────────────

const WalletDetails = () => {
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);
 const token = localStorage.getItem('token');
  const [filter, setFilter] = useState('All');
  const [isLifeTime, setIsLifeTime] = useState(true);
  const [openSection, setOpenSection] = useState('transaction');
 

  // API state
  const [walletData, setWalletData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchWalletHistory = useCallback(async () => {
    if (!userObject?._id) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${BASE_URL}/api/wallet/member/${userObject._id}/history`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      if (!res.ok) throw new Error(`Failed to fetch (${res.status})`);
      const data = await res.json();
      if (data.success) setWalletData(data);
      else throw new Error(data.message || 'Failed to load wallet data');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [userObject?._id, token]);

  useEffect(() => { fetchWalletHistory(); }, [fetchWalletHistory]);

  // Derived values — prefer API data, fall back to redux store
  const balance    = walletData?.wallet?.balance ?? userObject?.wallet?.balance ?? 0;
  const earned     = walletData?.summary?.total_earned ?? 0;
  const deducted   = walletData?.summary?.total_deducted ?? 0;
  const totalTx    = walletData?.summary?.total_transactions ?? 0;
  const apiUser    = walletData?.user ?? userObject;
  const rawTxList  = walletData?.transactions ?? [];

  // Filter transactions
  const filteredTx = rawTxList.filter(tx => {
    if (filter === 'All') return true;
    if (filter === 'Earned') return tx.direction === 'credit';
    if (filter === 'Spent')  return tx.direction === 'debit';
    return true;
  });

  return (
    <div
      className="h-screen overflow-hidden flex flex-col bg-gray-50 dark:bg-[#0a0a0a]"
      style={{  fontFamily: "'DM Sans', system-ui, sans-serif" }}
    >
      {/* ── Google Font ── */}
      <style>{`@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700;800&family=DM+Mono:wght@400;500&display=swap');`}</style>

      {/* ── Header ── */}
      <div className="sticky top-0 z-20 flex items-center gap-3 px-4 py-3.5 border-b border-gray-200 dark:border-white/[0.06] bg-white/90 dark:bg-[#0a0a0a]/90 backdrop-blur-xl">
        <button onClick={() => navigate(-1)}
          className="w-8 h-8 flex items-center justify-center rounded-xl bg-gray-100 dark:bg-white/[0.06] hover:bg-gray-200 dark:hover:bg-white/10 transition-colors text-gray-700 dark:text-white">
          <ArrowLeft size={16} />
        </button>
        <div className="flex items-center gap-2">
          <Wallet size={16} className="text-orange-400" />
          <h1 className="text-base font-bold text-gray-900 dark:text-white tracking-tight">Wallet & Coins</h1>
        </div>
        <button onClick={fetchWalletHistory}
          className={`ml-auto w-8 h-8 flex items-center justify-center rounded-xl bg-gray-100 dark:bg-white/[0.06] hover:bg-gray-200 dark:hover:bg-white/10 transition-colors text-gray-500 dark:text-white/60 ${loading ? 'animate-spin' : ''}`}>
          <RefreshCw size={14} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto px-4 pt-5 pb-6 space-y-3 scrollbar-hide dark:scrollbar-thumb-white/10">

        {/* ── Balance Card ── */}
        <div className="relative w-full rounded-3xl overflow-hidden p-6 text-white"
          style={{
            background: 'linear-gradient(135deg, #f97316 0%, #ea580c 40%, #c2410c 100%)',
            boxShadow: '0 24px 60px -12px rgba(249,115,22,0.45)'
          }}>
          {/* Decorative circles */}
          <div className="absolute -top-8 -right-8 w-40 h-40 rounded-full bg-white/10 blur-2xl pointer-events-none" />
          <div className="absolute -bottom-10 -left-6 w-32 h-32 rounded-full bg-black/20 blur-xl pointer-events-none" />
          <div className="absolute top-4 right-20 w-2 h-2 rounded-full bg-white/30" />
          <div className="absolute top-8 right-28 w-1 h-1 rounded-full bg-white/20" />

          {/* Top row */}
          <div className="relative flex items-center justify-between mb-5">
            <div className="flex items-center gap-2 text-white/70 text-xs font-medium">
              <div className="flex -space-x-1">
                <div className="w-3.5 h-3.5 rounded-full bg-white/40 border border-white/30" />
                <div className="w-3.5 h-3.5 rounded-full bg-white/20 border border-white/20" />
              </div>
              Available Balance
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-white/80">Lifetime</span>
              <button
                onClick={() => setIsLifeTime(!isLifeTime)}
                className={`w-9 h-5 rounded-full flex items-center px-0.5 transition-colors ${isLifeTime ? 'bg-white/30' : 'bg-black/30'}`}>
                <div className={`w-4 h-4 bg-white rounded-full shadow transition-transform ${isLifeTime ? 'translate-x-4' : 'translate-x-0'}`} />
              </button>
            </div>
          </div>

          {/* Balance */}
          <div className="relative mb-6">
            {loading && !walletData ? (
              <div className="flex items-center gap-2">
                <Loader2 size={20} className="animate-spin text-white/60" />
                <span className="text-white/60 text-sm">Loading…</span>
              </div>
            ) : (
              <div className="flex items-baseline gap-1.5">
                <span className="text-5xl font-extrabold tracking-tight" style={{ fontFamily: 'DM Mono, monospace' }}>
                  {formatCoins(balance)}
                </span>
                <span className="text-base font-semibold opacity-80 mb-1">coins</span>
              </div>
            )}
          </div>

          {/* Stats row */}
          <div className="relative flex justify-between">
            <StatPill label="Total Earned"   value={`+${formatCoins(earned)}`}   positive={true}  />
            <div className="w-px bg-white/20 self-stretch" />
            <StatPill label="Total Spent"    value={`-${formatCoins(deducted)}`} positive={false} />
            <div className="w-px bg-white/20 self-stretch" />
            <StatPill label="Transactions"   value={totalTx}                     positive={null}  />
          </div>
        </div>

        {/* ── Error banner ── */}
        {error && (
          <div className="flex items-center gap-2.5 px-4 py-3 rounded-xl border border-rose-200 dark:border-rose-500/20 bg-rose-50 dark:bg-rose-500/10 text-rose-500 dark:text-rose-400 text-sm">
            <AlertCircle size={15} className="shrink-0" />
            <span>{error}</span>
            <button onClick={fetchWalletHistory} className="ml-auto text-xs underline underline-offset-2 hover:no-underline">Retry</button>
          </div>
        )}

        {/* ── Transaction History Accordion ── */}
        <AccordionItem
          id="transaction"
          title="Transaction History"
          openSection={openSection}
          setOpenSection={setOpenSection}
          badge={totalTx > 0 ? totalTx : undefined}
        >
          {/* Filter tabs */}
          <div className="flex gap-1.5 mt-4 mb-4 p-1 bg-gray-100 dark:bg-white/[0.04] rounded-xl border border-gray-200 dark:border-white/[0.06]">
            {['All', 'Earned', 'Spent'].map((tab) => (
              <button
                key={tab}
                onClick={() => setFilter(tab)}
                className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition-all duration-200 ${
                  filter === tab
                    ? 'bg-orange-500 text-white shadow-lg shadow-orange-500/30'
                    : 'text-gray-400 dark:text-white/40 hover:text-gray-600 dark:hover:text-white/70'
                }`}>
                {tab}
              </button>
            ))}
          </div>

          {/* Transaction list */}
          {loading && !walletData ? (
            <TxSkeleton />
          ) : filteredTx.length === 0 ? (
            <div className="py-8 min-h-[120px] flex flex-col items-center justify-center gap-2 text-gray-400 dark:text-white/30">
              <Coins size={28} className="opacity-40" />
              <span className="text-sm">No transactions yet</span>
            </div>
          ) : (
            <div className="space-y-2 overflow-y-auto max-h-[340px] min-h-[120px] pr-1 scrollbar-thin scrollbar-track-transparent scrollbar-thumb-gray-300 dark:scrollbar-thumb-white/10">
              {filteredTx.map((tx, idx) => {
                const meta = getTxMeta(tx.type);
                const Icon = meta.icon;
                const isCredit = tx.direction === 'credit' || tx.amount > 0;
                return (
                  <div
                    key={tx._id || idx}
                    className="flex items-center gap-3.5 p-3.5 rounded-xl border border-gray-100 dark:border-white/[0.05] bg-gray-50 dark:bg-white/[0.02] hover:bg-gray-100 dark:hover:bg-white/[0.04] transition-colors group"
                  >
                    {/* Icon badge */}
                    <div className={`w-9 h-9 shrink-0 rounded-xl flex items-center justify-center ${meta.bg}`}>
                      <Icon size={15} className={meta.color} />
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-gray-800 dark:text-white/90 truncate leading-snug">
                        {tx.label || meta.label}
                      </p>
                      <div className="flex items-center gap-1.5 mt-0.5 flex-wrap">
                        <span className="text-[11px] text-gray-400 dark:text-white/30 font-mono">
                          {formatDate(tx.created_at)}
                        </span>
                        {tx.ad?.title && (
                          <>
                            <span className="text-gray-300 dark:text-white/15">·</span>
                            <span className="text-[11px] text-orange-400/70 truncate max-w-[100px]">
                              {tx.ad.title}
                            </span>
                          </>
                        )}
                      </div>
                      {tx.description && tx.description !== (tx.label || meta.label) && (
                        <p className="text-[11px] text-gray-400 dark:text-white/25 mt-0.5 truncate">{tx.description}</p>
                      )}
                    </div>

                    {/* Amount */}
                    <div className="flex flex-col items-end shrink-0 gap-0.5">
                      <span className={`text-sm font-bold font-mono ${isCredit ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {isCredit ? '+' : '-'}{Math.abs(tx.amount)}
                      </span>
                      <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded-full ${
                        tx.status === 'SUCCESS'
                          ? 'text-emerald-400/80 bg-emerald-400/10'
                          : 'text-rose-400/80 bg-rose-400/10'
                      }`}>
                        {tx.status}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </AccordionItem>

        {/* ── Account Details Accordion ── */}
        <AccordionItem id="account" title="Account Details" openSection={openSection} setOpenSection={setOpenSection}>
          <div className="space-y-4 mt-4">
            {/* User card */}
            <div className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 dark:bg-white/[0.03] border border-gray-200 dark:border-white/[0.06]">
              <div className="w-11 h-11 rounded-xl overflow-hidden bg-gray-200 dark:bg-white/10 flex items-center justify-center shrink-0">
                {apiUser?.avatar_url ? (
                  <img src={apiUser.avatar_url} alt="avatar" className="w-full h-full object-cover" />
                ) : (
                  <User size={18} className="text-gray-400 dark:text-white/40" />
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-bold text-gray-900 dark:text-white truncate">{apiUser?.full_name || apiUser?.username || '—'}</div>
                <div className="text-xs text-gray-400 dark:text-white/40">@{apiUser?.username || '—'}</div>
              </div>
              {apiUser?.role && (
                <span className="px-2 py-1 rounded-lg text-[11px] font-bold bg-orange-100 dark:bg-orange-500/15 text-orange-500 dark:text-orange-400 border border-orange-200 dark:border-orange-500/20 uppercase tracking-wide">
                  {apiUser.role}
                </span>
              )}
            </div>

            {/* Detail rows */}
            {[
              { label: 'Email',    value: userObject?.email,    icon: Mail  },
              { label: 'Phone',    value: userObject?.phone,    icon: Phone },
            ].map(({ label, value, icon: Icon }) => (
              <div key={label} className="flex items-center justify-between px-3 py-2.5 rounded-xl bg-gray-50 dark:bg-white/[0.03] border border-gray-100 dark:border-white/[0.04]">
                <span className="text-xs text-gray-500 dark:text-white/40 font-medium">{label}</span>
                <div className="flex items-center gap-1.5">
                  <Icon size={12} className="text-gray-400 dark:text-white/30" />
                  <span className="text-sm font-semibold text-gray-700 dark:text-white/80">{value || '—'}</span>
                </div>
              </div>
            ))}
            <div className="flex items-center justify-between px-3 py-2.5 rounded-xl bg-white/[0.03] border border-white/[0.04]">
              <span className="text-xs text-gray-500 dark:text-white/40 font-medium">Balance</span>
              <span className="text-sm font-bold text-orange-400">{Math.floor(Number(balance))} Coins</span>
            </div>
            <div className="flex items-center justify-between px-3 py-2.5 rounded-xl bg-white/[0.03] border border-white/[0.04]">
              <span className="text-xs text-gray-500 dark:text-white/40 font-medium">Currency</span>
              <span className="text-sm font-semibold text-gray-700 dark:text-white/80">{walletData?.wallet?.currency || userObject?.wallet?.currency || 'Coins'}</span>
            </div>

            {/* Vendor company details */}
            {userObject?.role === 'vendor' && (
              <div className="rounded-xl border border-gray-200 dark:border-white/[0.06] bg-gray-50 dark:bg-white/[0.02] p-3 space-y-2 mt-2">
                <div className="flex items-center justify-between mb-1">
                  <div className="flex items-center gap-2 text-sm font-semibold text-gray-600 dark:text-white/70">
                    <Building2 size={14} className="text-gray-400 dark:text-white/40" />
                    Company Details
                  </div>
                  {userObject?.company_details?.website && (
                    <a href={userObject.company_details.website} target="_blank" rel="noreferrer"
                      className="text-xs text-orange-400 hover:underline">Visit site</a>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    ['Company',        userObject?.company_details?.company_name],
                    ['Legal Name',     userObject?.company_details?.legal_business_name],
                    ['Industry',       userObject?.company_details?.industry],
                    ['Website',        userObject?.company_details?.website],
                    ['Business Email', userObject?.company_details?.business_email],
                    ['Business Phone', userObject?.company_details?.business_phone],
                    ['City',           userObject?.company_details?.city],
                    ['Country',        userObject?.company_details?.country],
                  ].map(([label, value]) => (
                    <div key={label} className="flex flex-col gap-0.5 px-3 py-2 rounded-lg bg-white dark:bg-white/[0.03] border border-gray-100 dark:border-transparent">
                      <span className="text-[10px] text-gray-400 dark:text-white/30 uppercase tracking-wide">{label}</span>
                      <span className="text-xs font-semibold text-gray-700 dark:text-white/70 truncate">{value || '—'}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </AccordionItem>


        {/* ── Help Accordion ── */}
        <AccordionItem id="help" title="Help" openSection={openSection} setOpenSection={setOpenSection}>
          <div className="space-y-1 mt-4">
            {['How do coins work?', 'Why is my balance changed?', 'Contact support'].map((item) => (
              <button key={item}
                className="w-full text-left px-3 py-3 rounded-xl text-sm text-gray-500 dark:text-white/50 hover:text-gray-800 dark:hover:text-white/80 hover:bg-gray-100 dark:hover:bg-white/[0.04] transition-colors">
                {item}
              </button>
            ))}
          </div>
        </AccordionItem>

      </div>
    </div>
  );
};

export default WalletDetails;