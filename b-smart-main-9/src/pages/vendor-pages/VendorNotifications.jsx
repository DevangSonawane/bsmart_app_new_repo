/**
 * VendorNotifications.jsx  —  Vendor-specific notification page
 * Extra types: ad_approved · ad_rejected · ad_spend · wallet_credit · wallet_debit · campaign
 */

import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bell, Megaphone, Wallet, CheckCircle2, XCircle, TrendingUp,
  TrendingDown, RefreshCw, CheckCheck, Trash2, AlertCircle,
  Loader2, ChevronLeft, ChevronRight, BadgeCheck, Zap,
  Heart, MessageCircle, UserPlus, Wifi, WifiOff, Target, Receipt
} from "lucide-react";
import { useNotificationSocket } from "../../hooks/useNotificationSocket";

// ─── Helpers ──────────────────────────────────────────────────────────────────
const timeAgo = (d) => {
  if (!d) return "";
  const diff = Date.now() - new Date(d).getTime();
  const s = Math.floor(diff / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const day = Math.floor(h / 24);
  if (day < 7) return `${day}d ago`;
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
};

const fmt = (n) => Number(n || 0).toLocaleString("en-IN");

// ─── Vendor-specific type config ──────────────────────────────────────────────
const TYPE_CONFIG = {
  // Ad lifecycle
  ad_approved:  { icon: BadgeCheck,    bg: "bg-green-100 dark:bg-green-900/30",   color: "text-green-600",   label: "Ad Approved",  accent: "border-l-green-500"  },
  ad_rejected:  { icon: XCircle,       bg: "bg-red-100 dark:bg-red-900/30",       color: "text-red-600",     label: "Ad Rejected",  accent: "border-l-red-500"    },
  ad_submitted: { icon: Megaphone,     bg: "bg-blue-100 dark:bg-blue-900/30",     color: "text-blue-600",    label: "Ad Submitted", accent: "border-l-blue-400"   },
  ad_expired:   { icon: XCircle,       bg: "bg-gray-100 dark:bg-gray-800",        color: "text-gray-500",    label: "Ad Expired",   accent: "border-l-gray-400"   },
  // Engagement on ads
  ad_like:      { icon: Heart,         bg: "bg-pink-100 dark:bg-pink-900/30",     color: "text-pink-500",    label: "Ad Like",      accent: "border-l-pink-400"   },
  ad_comment:   { icon: MessageCircle, bg: "bg-orange-100 dark:bg-orange-900/30", color: "text-orange-500",  label: "Ad Comment",   accent: "border-l-orange-400" },
  ad_view:      { icon: Target,        bg: "bg-sky-100 dark:bg-sky-900/30",       color: "text-sky-500",     label: "Ad View",      accent: "border-l-sky-400"    },
  // Wallet
  wallet_credit:{ icon: TrendingUp,    bg: "bg-emerald-100 dark:bg-emerald-900/30",color:"text-emerald-600", label: "Wallet Credit",accent: "border-l-emerald-500"},
  wallet_debit: { icon: TrendingDown,  bg: "bg-rose-100 dark:bg-rose-900/30",     color: "text-rose-600",    label: "Wallet Debit", accent: "border-l-rose-500"   },
  ad_spend:     { icon: Receipt,       bg: "bg-amber-100 dark:bg-amber-900/30",   color: "text-amber-600",   label: "Ad Spend",     accent: "border-l-amber-400"  },
  refund:       { icon: Wallet,        bg: "bg-teal-100 dark:bg-teal-900/30",     color: "text-teal-600",    label: "Refund",       accent: "border-l-teal-400"   },
  // General
  follow:       { icon: UserPlus,      bg: "bg-blue-100 dark:bg-blue-900/30",     color: "text-blue-600",    label: "Follow",       accent: "border-l-blue-400"   },
  campaign:     { icon: Zap,           bg: "bg-purple-100 dark:bg-purple-900/30", color: "text-purple-600",  label: "Campaign",     accent: "border-l-purple-400" },
};
const getType = (t) => TYPE_CONFIG[t] || { icon: Bell, bg: "bg-gray-100 dark:bg-gray-800", color: "text-gray-400", label: "Notification", accent: "border-l-gray-300" };

const FILTER_TABS = [
  { key: "all",          label: "All",           emoji: "" },
  { key: "unread",       label: "Unread",        emoji: "🔵" },
  { key: "ad_approved",  label: "Approvals",     emoji: "✅" },
  { key: "ad_rejected",  label: "Rejections",    emoji: "❌" },
  { key: "ad_like",      label: "Engagement",    emoji: "❤️" },
  { key: "wallet_credit",label: "Credits",       emoji: "💰" },
  { key: "ad_spend",     label: "Spend",         emoji: "💸" },
];

const LIMIT = 15;

// ─── Avatar ───────────────────────────────────────────────────────────────────
const Avatar = ({ name, url }) => {
  const initials = (name || "?").split(" ").map(w => w[0]).slice(0, 2).join("").toUpperCase();
  if (url) return <img src={url} alt={name} className="w-11 h-11 rounded-full object-cover flex-shrink-0" onError={e => { e.currentTarget.style.display = "none"; }} />;
  return (
    <div className="w-11 h-11 rounded-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
      {initials}
    </div>
  );
};

// ─── WS Status ────────────────────────────────────────────────────────────────
const WsIndicator = ({ status }) => {
  if (status === "open")    return <span className="flex items-center gap-1 text-[10px] font-bold text-green-600 dark:text-green-400"><Wifi size={10} />Live</span>;
  if (status === "polling") return <span className="flex items-center gap-1 text-[10px] font-bold text-amber-500"><WifiOff size={10} />Polling</span>;
  return <span className="flex items-center gap-1 text-[10px] font-bold text-gray-400"><WifiOff size={10} />Connecting…</span>;
};

// ─── Coin amount badge ─────────────────────────────────────────────────────────
const CoinBadge = ({ notif }) => {
  const walletTypes = ["wallet_credit", "wallet_debit", "ad_spend", "refund"];
  if (!walletTypes.includes(notif.type) || !notif.metadata?.amount) return null;
  const isCredit = ["wallet_credit", "refund"].includes(notif.type);
  return (
    <span className={`text-xs font-black px-2 py-0.5 rounded-full flex-shrink-0 ${isCredit ? "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400" : "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400"}`}>
      {isCredit ? "+" : "−"}₹{fmt(notif.metadata.amount)}
    </span>
  );
};

// ─── Single notification row ───────────────────────────────────────────────────
const NotifRow = ({ notif, onMarkRead, onDelete }) => {
  const navigate = useNavigate();
  const cfg = getType(notif.type);
  const Icon = cfg.icon;
  const sender = notif.sender?.full_name || notif.sender?.username || "System";

  const handleClick = async () => {
    if (!notif.isRead) await onMarkRead(notif._id);
    if (notif.link) navigate(notif.link);
  };

  return (
    <div onClick={handleClick}
      className={`group relative flex items-start gap-3.5 pl-6 pr-5 py-4 cursor-pointer transition-colors hover:bg-gray-50 dark:hover:bg-white/[0.03] border-l-2 ${cfg.accent} ${!notif.isRead ? "bg-blue-50/40 dark:bg-blue-950/20" : ""}`}>

      {/* Unread dot */}
      {!notif.isRead && (
        <span className="absolute left-2 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-blue-500 flex-shrink-0" />
      )}

      {/* Avatar + type icon */}
      <div className="relative flex-shrink-0">
        <Avatar name={sender} url={notif.sender?.avatar_url} />
        <div className={`absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full ${cfg.bg} flex items-center justify-center ring-2 ring-white dark:ring-gray-900`}>
          <Icon size={10} className={cfg.color} />
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 pt-0.5">
        <div className="flex items-start justify-between gap-2">
          <p className={`text-sm leading-snug flex-1 ${!notif.isRead ? "font-semibold text-gray-900 dark:text-white" : "text-gray-600 dark:text-gray-300"}`}>
            {notif.message}
          </p>
          <CoinBadge notif={notif} />
        </div>
        {/* Ad title if present */}
        {notif.metadata?.adTitle && (
          <p className="text-xs text-orange-500 dark:text-orange-400 mt-0.5 font-medium truncate max-w-xs">
            📢 {notif.metadata.adTitle}
          </p>
        )}
        <div className="flex items-center gap-2 mt-1.5">
          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${cfg.bg} ${cfg.color}`}>{cfg.label}</span>
          <span className="text-[11px] text-gray-400">{timeAgo(notif.createdAt)}</span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0 pt-0.5">
        {!notif.isRead && (
          <button onClick={e => { e.stopPropagation(); onMarkRead(notif._id); }}
            className="p-1.5 rounded-lg hover:bg-blue-100 dark:hover:bg-blue-900/30 text-blue-500" title="Mark read">
            <CheckCheck size={13} />
          </button>
        )}
        <button onClick={e => { e.stopPropagation(); onDelete(notif._id); }}
          className="p-1.5 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/30 text-red-400" title="Delete">
          <Trash2 size={13} />
        </button>
      </div>
    </div>
  );
};

// ─── Stats bar (vendor-specific) ──────────────────────────────────────────────
const StatsBar = ({ notifications }) => {
  const counts = {
    approvals:   notifications.filter(n => n.type === "ad_approved").length,
    rejections:  notifications.filter(n => n.type === "ad_rejected").length,
    engagement:  notifications.filter(n => ["ad_like","ad_comment","ad_view"].includes(n.type)).length,
    wallet:      notifications.filter(n => ["wallet_credit","wallet_debit","ad_spend","refund"].includes(n.type)).length,
  };

  return (
    <div className="grid grid-cols-4 gap-3 mb-5">
      {[
        { label: "Approvals",  value: counts.approvals,  color: "text-green-600 dark:text-green-400",  bg: "bg-green-50 dark:bg-green-900/20"  },
        { label: "Rejections", value: counts.rejections, color: "text-red-600 dark:text-red-400",      bg: "bg-red-50 dark:bg-red-900/20"      },
        { label: "Engagement", value: counts.engagement, color: "text-pink-600 dark:text-pink-400",    bg: "bg-pink-50 dark:bg-pink-900/20"    },
        { label: "Wallet",     value: counts.wallet,     color: "text-amber-600 dark:text-amber-400",  bg: "bg-amber-50 dark:bg-amber-900/20"  },
      ].map((s, i) => (
        <div key={i} className={`${s.bg} rounded-xl p-3 text-center border border-transparent`}>
          <div className={`text-xl font-black ${s.color}`}>{s.value}</div>
          <div className="text-[10px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">{s.label}</div>
        </div>
      ))}
    </div>
  );
};

// ─── Main page ────────────────────────────────────────────────────────────────
export default function VendorNotifications() {
  const [activeTab,  setActiveTab]  = useState("all");
  const [page,       setPage]       = useState(1);
  const [markingAll, setMarkingAll] = useState(false);

  const {
    notifications, unreadCount, total, loading, error, wsStatus,
    markRead, markAllRead, deleteNotif, refresh,
  } = useNotificationSocket({ limit: LIMIT, page, typeFilter: activeTab });

  const totalPages = Math.ceil(total / LIMIT);

  const handleTabChange = (tab) => { setActiveTab(tab); setPage(1); };
  const handleMarkAll = async () => { setMarkingAll(true); await markAllRead(); setMarkingAll(false); };

  const getPageNums = () => {
    const w = Math.min(5, totalPages);
    let start = Math.max(1, page - Math.floor(w / 2));
    let end = Math.min(totalPages, start + w - 1);
    start = Math.max(1, end - w + 1);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black">
      <div className="max-w-3xl mx-auto px-4 py-8">

        {/* ── Header ──────────────────────────────────────────────────────── */}
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-orange-500 via-pink-600 to-purple-600 flex items-center justify-center shadow-lg shadow-pink-500/20">
              <Megaphone size={20} className="text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-gray-900 dark:text-white leading-tight">Vendor Notifications</h1>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-[11px] px-2 py-0.5 rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400 font-bold">Vendor</span>
                {unreadCount > 0 && (
                  <span className="text-xs font-semibold text-blue-600 dark:text-blue-400">{unreadCount} unread</span>
                )}
                <WsIndicator status={wsStatus} />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={refresh}
              className="p-2 rounded-xl border border-gray-200 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
              <RefreshCw size={15} className="text-gray-500" />
            </button>
            {unreadCount > 0 && (
              <button onClick={handleMarkAll} disabled={markingAll}
                className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 text-white text-xs font-bold hover:opacity-90 disabled:opacity-60 transition-opacity shadow-sm">
                {markingAll ? <Loader2 size={12} className="animate-spin" /> : <CheckCheck size={12} />}
                Mark all read
              </button>
            )}
          </div>
        </div>

        {/* ── Stats bar ───────────────────────────────────────────────────── */}
        {!loading && notifications.length > 0 && (
          <StatsBar notifications={notifications} />
        )}

        {/* ── Filter tabs ─────────────────────────────────────────────────── */}
        <div className="flex gap-1.5 overflow-x-auto pb-1 mb-4 scrollbar-hide">
          {FILTER_TABS.map(tab => (
            <button key={tab.key} onClick={() => handleTabChange(tab.key)}
              className={`flex-shrink-0 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all whitespace-nowrap
                ${activeTab === tab.key
                  ? "bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-sm shadow-pink-500/20"
                  : "bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 text-gray-500 hover:border-gray-300"}`}>
              {tab.emoji && <span className="mr-1">{tab.emoji}</span>}{tab.label}
            </button>
          ))}
        </div>

        {/* ── Notification list ────────────────────────────────────────────── */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 size={28} className="animate-spin text-orange-500" />
              <span className="text-sm text-gray-400">Loading notifications…</span>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-16 gap-3 text-red-500">
              <AlertCircle size={24} />
              <span className="text-sm">{error}</span>
              <button onClick={refresh} className="text-xs underline text-blue-500">Retry</button>
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                <Megaphone size={24} className="text-gray-300 dark:text-gray-600" />
              </div>
              <p className="text-sm font-medium text-gray-400">No notifications</p>
              <p className="text-xs text-gray-400">
                {activeTab !== "all" ? "Try a different filter" : "You're all caught up!"}
              </p>
              {activeTab !== "all" && (
                <button onClick={() => handleTabChange("all")} className="text-xs text-orange-500 underline">View all</button>
              )}
            </div>
          ) : (
            <div className="divide-y divide-gray-50 dark:divide-gray-800/80">
              {notifications.map(n => (
                <NotifRow key={n._id} notif={n} onMarkRead={markRead} onDelete={deleteNotif} />
              ))}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && !loading && (
            <div className="flex items-center justify-between px-5 py-3 border-t border-gray-100 dark:border-gray-800">
              <span className="text-xs text-gray-400">Page {page} of {totalPages} · {total} total</span>
              <div className="flex items-center gap-1">
                <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                  className="p-1.5 rounded-lg border border-gray-200 dark:border-gray-700 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <ChevronLeft size={14} />
                </button>
                {getPageNums().map(p => (
                  <button key={p} onClick={() => setPage(p)}
                    className={`w-7 h-7 rounded-lg text-xs font-bold transition-colors
                      ${page === p
                        ? "bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-sm"
                        : "border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"}`}>
                    {p}
                  </button>
                ))}
                <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
                  className="p-1.5 rounded-lg border border-gray-200 dark:border-gray-700 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>
          )}
        </div>

      </div>
    </div>
  );
}