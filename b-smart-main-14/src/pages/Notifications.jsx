/**
 * Notifications.jsx  —  Regular member notification page
 * Filters: All · Unread · Likes · Comments · Follows · Mentions
 */

import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bell, Heart, MessageCircle, UserPlus, AtSign,
  RefreshCw, CheckCheck, Trash2, AlertCircle,
  Loader2, ChevronLeft, ChevronRight, Bookmark, Star, Wifi, WifiOff
} from "lucide-react";
import { useNotificationSocket } from "../hooks/useNotificationSocket";

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

// ─── Type config (member types only) ─────────────────────────────────────────
const TYPE_CONFIG = {
  like:    { icon: Heart,          bg: "bg-pink-100 dark:bg-pink-900/30",    color: "text-pink-500",    label: "Like"     },
  comment: { icon: MessageCircle,  bg: "bg-orange-100 dark:bg-orange-900/30",color: "text-orange-500",  label: "Comment"  },
  follow:  { icon: UserPlus,       bg: "bg-blue-100 dark:bg-blue-900/30",    color: "text-blue-500",    label: "Follow"   },
  mention: { icon: AtSign,         bg: "bg-purple-100 dark:bg-purple-900/30",color: "text-purple-500",  label: "Mention"  },
  save:    { icon: Bookmark,       bg: "bg-teal-100 dark:bg-teal-900/30",    color: "text-teal-500",    label: "Save"     },
  reward:  { icon: Star,           bg: "bg-yellow-100 dark:bg-yellow-900/30",color: "text-yellow-500",  label: "Reward"   },
};
const getType = (t) => TYPE_CONFIG[t] || { icon: Bell, bg: "bg-gray-100 dark:bg-gray-800", color: "text-gray-400", label: "Notification" };

const FILTER_TABS = [
  { key: "all",     label: "All"      },
  { key: "unread",  label: "Unread"   },
  { key: "like",    label: "❤️ Likes"  },
  { key: "comment", label: "💬 Comments"},
  { key: "follow",  label: "👤 Follows" },
  { key: "mention", label: "@ Mentions"},
];

const LIMIT = 15;

// ─── Avatar ───────────────────────────────────────────────────────────────────
const Avatar = ({ name, url }) => {
  const initials = (name || "U").split(" ").map(w => w[0]).slice(0, 2).join("").toUpperCase();
  if (url) return (
    <img src={url} alt={name}
      className="w-11 h-11 rounded-full object-cover flex-shrink-0"
      onError={e => { e.currentTarget.style.display = "none"; }} />
  );
  return (
    <div className="w-11 h-11 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
      {initials}
    </div>
  );
};

// ─── WS Status pill ───────────────────────────────────────────────────────────
const WsIndicator = ({ status }) => {
  if (status === "open")     return <span className="flex items-center gap-1 text-[10px] font-bold text-green-600 dark:text-green-400"><Wifi size={10} />Live</span>;
  if (status === "polling")  return <span className="flex items-center gap-1 text-[10px] font-bold text-amber-500"><WifiOff size={10} />Polling</span>;
  return <span className="flex items-center gap-1 text-[10px] font-bold text-gray-400"><WifiOff size={10} />Connecting…</span>;
};

// ─── Single row ───────────────────────────────────────────────────────────────
const NotifRow = ({ notif, onMarkRead, onDelete }) => {
  const navigate = useNavigate();
  const cfg = getType(notif.type);
  const Icon = cfg.icon;
  const sender = notif.sender?.full_name || notif.sender?.username || "Someone";

  const handleClick = async () => {
    if (!notif.isRead) await onMarkRead(notif._id);
    if (notif.link) navigate(notif.link);
  };

  return (
    <div onClick={handleClick}
      className={`group relative flex items-start gap-3.5 px-5 py-4 cursor-pointer transition-colors hover:bg-gray-50 dark:hover:bg-white/[0.03] ${!notif.isRead ? "bg-blue-50/50 dark:bg-blue-950/20" : ""}`}>

      {/* Unread dot */}
      {!notif.isRead && (
        <span className="absolute left-2 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-blue-500" />
      )}

      {/* Avatar + badge */}
      <div className="relative flex-shrink-0">
        <Avatar name={sender} url={notif.sender?.avatar_url} />
        <div className={`absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full ${cfg.bg} flex items-center justify-center ring-2 ring-white dark:ring-[#111]`}>
          <Icon size={11} className={cfg.color} />
        </div>
      </div>

      {/* Text */}
      <div className="flex-1 min-w-0 pt-0.5">
        <p className={`text-sm leading-snug ${!notif.isRead ? "font-semibold text-gray-900 dark:text-white" : "text-gray-600 dark:text-gray-300"}`}>
          {notif.message}
        </p>
        <div className="flex items-center gap-2 mt-1.5">
          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${cfg.bg} ${cfg.color}`}>{cfg.label}</span>
          <span className="text-[11px] text-gray-400">{timeAgo(notif.createdAt)}</span>
        </div>
      </div>

      {/* Hover actions */}
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

// ─── Main page ────────────────────────────────────────────────────────────────
export default function Notifications() {
  const [activeTab, setActiveTab] = useState("all");
  const [page,      setPage]      = useState(1);
  const [markingAll, setMarkingAll] = useState(false);

  const {
    notifications, unreadCount, total, loading, error, wsStatus,
    markRead, markAllRead, deleteNotif, refresh,
  } = useNotificationSocket({ limit: LIMIT, page, typeFilter: activeTab });

  const totalPages = Math.ceil(total / LIMIT);

  const handleTabChange = (tab) => { setActiveTab(tab); setPage(1); };

  const handleMarkAll = async () => {
    setMarkingAll(true);
    await markAllRead();
    setMarkingAll(false);
  };

  const getPageNums = () => {
    const w = Math.min(5, totalPages);
    let start = Math.max(1, page - Math.floor(w / 2));
    let end = Math.min(totalPages, start + w - 1);
    start = Math.max(1, end - w + 1);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black">
      <div className="max-w-2xl mx-auto px-4 py-8">

        {/* ── Header ──────────────────────────────────────────────────────── */}
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-center gap-3">
            {/* Icon */}
            <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center shadow-md shadow-pink-500/20">
              <Bell size={20} className="text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-gray-900 dark:text-white leading-tight">Notifications</h1>
              <div className="flex items-center gap-2 mt-0.5">
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
                className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-blue-600 text-white text-xs font-bold hover:bg-blue-700 disabled:opacity-60 transition-colors">
                {markingAll ? <Loader2 size={12} className="animate-spin" /> : <CheckCheck size={12} />}
                Mark all read
              </button>
            )}
          </div>
        </div>

        {/* ── Filter tabs ─────────────────────────────────────────────────── */}
        <div className="flex gap-1.5 overflow-x-auto pb-1 mb-4 scrollbar-hide">
          {FILTER_TABS.map(tab => (
            <button key={tab.key} onClick={() => handleTabChange(tab.key)}
              className={`flex-shrink-0 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all whitespace-nowrap
                ${activeTab === tab.key
                  ? "bg-gray-900 dark:bg-white text-white dark:text-black shadow-sm"
                  : "bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 text-gray-500 hover:border-gray-300 dark:hover:border-gray-600"}`}>
              {tab.label}
            </button>
          ))}
        </div>

        {/* ── List card ───────────────────────────────────────────────────── */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3">
              <Loader2 size={28} className="animate-spin text-pink-500" />
              <span className="text-sm text-gray-400">Loading…</span>
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
                <Bell size={24} className="text-gray-300 dark:text-gray-600" />
              </div>
              <p className="text-sm font-medium text-gray-400">No notifications here</p>
              {activeTab !== "all" && (
                <button onClick={() => handleTabChange("all")} className="text-xs text-pink-500 underline">View all</button>
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
                      ${page === p ? "bg-gray-900 dark:bg-white text-white dark:text-black" : "border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"}`}>
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