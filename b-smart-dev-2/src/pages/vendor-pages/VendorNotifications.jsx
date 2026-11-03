/**
 * VendorNotifications.jsx  —  Vendor notification feed
 * API: GET /api/notifications?filter=<key>&page=&limit=
 *      GET /api/notifications/tab-counts
 *      PATCH /api/notifications/mark-all-read
 */

import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bell, Megaphone, Wallet, CheckCircle2, XCircle, TrendingUp,
  TrendingDown, RefreshCw, CheckCheck, Trash2, AlertCircle,
  Loader2, ChevronLeft, ChevronRight, BadgeCheck, Zap,
  Heart, MessageCircle, UserPlus, Wifi, WifiOff, Target, Receipt
} from "lucide-react";
import api from "../../lib/api";
import { useNotificationSocket } from "../../hooks/useNotificationSocket";
import { acceptFollowRequest, declineFollowRequest } from "../../services/followService";
import Avatar from "../../components/Avatar";

// ─── Helpers ──────────────────────────────────────────────────────────────────
const timeAgo = (d) => {
  if (!d) return "";
  const diff = Date.now() - new Date(d).getTime();
  const s = Math.floor(diff / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  const day = Math.floor(h / 24);
  if (day < 7) return `${day}d`;
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
};

const fmt = (n) => Number(n || 0).toLocaleString("en-IN");

const groupByTime = (notifications) => {
  const now  = Date.now();
  const DAY  = 86400000;
  const WEEK = 7 * DAY;
  const groups = { new: [], week: [], earlier: [] };
  notifications.forEach((n) => {
    const age = now - new Date(n.createdAt).getTime();
    if (age < DAY)       groups.new.push(n);
    else if (age < WEEK) groups.week.push(n);
    else                 groups.earlier.push(n);
  });
  return groups;
};

// ─── Type config ──────────────────────────────────────────────────────────────
const TYPE_CONFIG = {
  ad_approved:     { icon: BadgeCheck,    bg: "bg-green-500",   label: "Spotlight Approved"  },
  ad_rejected:     { icon: XCircle,       bg: "bg-red-500",     label: "Spotlight Rejected"  },
  ad_submitted:    { icon: Megaphone,     bg: "bg-blue-500",    label: "Spotlight Submitted" },
  ad_expired:      { icon: XCircle,       bg: "bg-gray-400",    label: "Spotlight Expired"   },
  ad_like:         { icon: Heart,         bg: "bg-pink-500",    label: "Spotlight Like"      },
  ad_comment:      { icon: MessageCircle, bg: "bg-orange-500",  label: "Spotlight Comment"   },
  ad_view:         { icon: Target,        bg: "bg-sky-500",     label: "Spotlight View"      },
  wallet_credit:   { icon: TrendingUp,    bg: "bg-emerald-500", label: "Wallet Credit"       },
  wallet_debit:    { icon: TrendingDown,  bg: "bg-rose-500",    label: "Wallet Debit"        },
  ad_spend:        { icon: Receipt,       bg: "bg-amber-500",   label: "Spotlight Spend"     },
  refund:          { icon: Wallet,        bg: "bg-teal-500",    label: "Refund"              },
  follow:          { icon: UserPlus,      bg: "bg-blue-500",    label: "Follow"              },
  follow_request:  { icon: UserPlus,      bg: "bg-blue-500",    label: "Follow Request"      },
  follow_accepted: { icon: CheckCircle2,  bg: "bg-green-500",   label: "Request Accepted"    },
  campaign:        { icon: Zap,           bg: "bg-purple-500",  label: "Campaign"            },
};
const getType = (t) =>
  TYPE_CONFIG[t] || { icon: Bell, bg: "bg-gray-400", label: "Notification" };

// ─── Filter tabs — keys match API filter query param values ───────────────────
const FILTER_TABS = [
  { key: "all",        label: "All",        emoji: "🔔" },
  { key: "unread",     label: "Unread",     emoji: "🔵", showBadge: true },
  { key: "approvals",  label: "Approvals",  emoji: "✅" },
  { key: "rejections", label: "Rejections", emoji: "❌" },
  { key: "engagement", label: "Engagement", emoji: "❤️" },
  { key: "credits",    label: "Credits",    emoji: "🪙" },
  { key: "spend",      label: "Spend",      emoji: "💸" },
];

const LIMIT = 20;

// ─── WS live indicator ────────────────────────────────────────────────────────
const WsIndicator = ({ status }) => {
  if (status === "open")
    return <span className="flex items-center gap-1 text-[10px] font-bold text-green-500"><Wifi size={9} />Live</span>;
  if (status === "polling")
    return <span className="flex items-center gap-1 text-[10px] font-bold text-amber-500"><WifiOff size={9} />Polling</span>;
  return <span className="flex items-center gap-1 text-[10px] font-bold text-gray-400"><WifiOff size={9} />…</span>;
};

// ─── Coin amount pill ─────────────────────────────────────────────────────────
const CoinBadge = ({ notif }) => {
  const walletTypes = ["wallet_credit", "wallet_debit", "ad_spend", "refund"];
  if (!walletTypes.includes(notif.type) || !notif.metadata?.amount) return null;
  const isCredit = ["wallet_credit", "refund"].includes(notif.type);
  return (
    <span className={`text-xs font-black px-2 py-0.5 rounded-full flex-shrink-0 ${
      isCredit
        ? "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
        : "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400"
    }`}>
      {isCredit ? "+" : "−"}₹{fmt(notif.metadata.amount)}
    </span>
  );
};

// ─── Section label ────────────────────────────────────────────────────────────
const SectionLabel = ({ label }) => (
  <div className="px-4 pt-5 pb-1.5">
    <span className="text-[13px] font-bold text-gray-900 dark:text-white">{label}</span>
  </div>
);

// ─── Single notification row ──────────────────────────────────────────────────
const NotifRow = ({ notif, onMarkRead, onDelete, onFollowDecision, actionState }) => {
  const navigate     = useNavigate();
  const cfg          = getType(notif.type);
  const Icon         = cfg.icon;
  const sender       = notif.sender?.full_name || notif.sender?.username || "System";
  const senderAvatar = notif.sender?.avatar_url || null;
  const isFollowReq  = notif.type === "follow_request";
  const isActing     = Boolean(actionState);
  const hasCoin      = ["wallet_credit", "wallet_debit", "ad_spend", "refund"].includes(notif.type)
    && notif.metadata?.amount;

  const handleClick = async () => {
    if (!notif.isRead) await onMarkRead(notif._id);
    if (notif.link) navigate(notif.link);
  };

  return (
    <div
      onClick={handleClick}
      className={`group flex items-center gap-3 px-4 py-3 cursor-pointer transition-colors active:bg-gray-50 dark:active:bg-white/5 ${
        !notif.isRead
          ? "bg-blue-50/40 dark:bg-blue-950/10"
          : "hover:bg-gray-50 dark:hover:bg-white/[0.02]"
      }`}
    >
      {/* Avatar + type badge */}
      <div className="relative shrink-0">
        {senderAvatar ? (
          <img src={senderAvatar} alt={sender} className="w-11 h-11 rounded-full object-cover" />
        ) : (
          <Avatar name={sender} size="md" />
        )}
        <div className={`absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full ${cfg.bg} flex items-center justify-center ring-2 ring-white dark:ring-black`}>
          <Icon size={10} className="text-white" strokeWidth={2.5} />
        </div>
      </div>

      {/* Message + meta */}
      <div className="flex-1 min-w-0">
        <p className={`text-sm leading-snug break-words ${
          !notif.isRead ? "text-gray-900 dark:text-white" : "text-gray-700 dark:text-gray-300"
        }`}>
          {notif.message}
          <span className="text-gray-400 dark:text-gray-500 text-xs font-normal ml-1.5">
            {timeAgo(notif.createdAt)}
          </span>
        </p>

        {notif.metadata?.adTitle && (
          <p className="text-xs text-orange-500 dark:text-orange-400 mt-0.5 font-medium truncate">
            📢 {notif.metadata.adTitle}
          </p>
        )}

        {isFollowReq && (
          <div className="mt-2.5 flex items-center gap-2">
            <button
              type="button"
              disabled={isActing}
              onClick={(e) => { e.stopPropagation(); onFollowDecision?.(notif, "accept"); }}
              className="px-4 py-1.5 rounded-lg bg-blue-500 text-white text-xs font-bold hover:bg-blue-600 disabled:opacity-60 transition-colors"
            >
              {actionState === "accept" ? "Accepting…" : "Confirm"}
            </button>
            <button
              type="button"
              disabled={isActing}
              onClick={(e) => { e.stopPropagation(); onFollowDecision?.(notif, "decline"); }}
              className="px-4 py-1.5 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 text-xs font-bold hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-60 transition-colors"
            >
              {actionState === "decline" ? "Declining…" : "Delete"}
            </button>
          </div>
        )}
      </div>

      {/* Right: coin badge + hover actions */}
      <div className="flex items-center gap-1.5 shrink-0">
        {hasCoin && <CoinBadge notif={notif} />}
        <div className="flex flex-col gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          {!notif.isRead && (
            <button
              onClick={(e) => { e.stopPropagation(); onMarkRead(notif._id); }}
              className="p-1 rounded-md hover:bg-blue-100 dark:hover:bg-blue-900/30 text-blue-400"
              title="Mark read"
            >
              <CheckCheck size={14} />
            </button>
          )}
          <button
            onClick={(e) => { e.stopPropagation(); onDelete(notif._id); }}
            className="p-1 rounded-md hover:bg-red-100 dark:hover:bg-red-900/30 text-gray-300 dark:text-gray-600 hover:text-red-400"
            title="Delete"
          >
            <Trash2 size={14} />
          </button>
        </div>
      </div>
    </div>
  );
};

// ─── Main page ────────────────────────────────────────────────────────────────
export default function VendorNotifications() {
  const [activeTab,          setActiveTab]          = useState("all");
  const [page,               setPage]               = useState(1);
  const [markingAll,         setMarkingAll]         = useState(false);
  const [tabCounts,          setTabCounts]          = useState({});
  const [tabCountsLoading,   setTabCountsLoading]   = useState(true);
  const [followActionLoading, setFollowActionLoading] = useState({});

  // Pass filter key directly — hook forwards it as ?filter= to the API
  const {
    notifications, total, loading, error, wsStatus,
    markRead, markAllRead, deleteNotif, refresh,
  } = useNotificationSocket({
    limit:  LIMIT,
    page,
    filter: activeTab === "all" ? undefined : activeTab,
  });

  const totalPages = Math.ceil(total / LIMIT);
  const groups     = groupByTime(notifications);
  const hasGroups  = groups.new.length + groups.week.length + groups.earlier.length > 0;

  // ── Fetch tab badge counts ─────────────────────────────────────────────────
  const fetchTabCounts = useCallback(async () => {
    try {
      setTabCountsLoading(true);
      const res = await api.get("/notifications/tab-counts");
      setTabCounts(res.data?.tabs || {});
    } catch {
      // non-fatal — badges simply won't show
    } finally {
      setTabCountsLoading(false);
    }
  }, []);

  useEffect(() => { fetchTabCounts(); }, [fetchTabCounts]);

  // ── Handlers ───────────────────────────────────────────────────────────────
  const handleTabChange = (tab) => { setActiveTab(tab); setPage(1); };

  const handleMarkAll = async () => {
    setMarkingAll(true);
    try {
      await api.patch("/notifications/mark-all-read");
      await markAllRead();
      await fetchTabCounts();
    } catch (err) {
      console.error("Mark all read failed", err);
    } finally {
      setMarkingAll(false);
    }
  };

  const handleFollowDecision = async (notif, decision) => {
    const notifId     = notif?._id;
    const requesterId = notif?.sender?._id || notif?.sender?.id;
    if (!notifId || !requesterId || !["accept", "decline"].includes(decision)) return;
    setFollowActionLoading((prev) => ({ ...prev, [notifId]: decision }));
    try {
      if (decision === "accept") await acceptFollowRequest(requesterId);
      else                       await declineFollowRequest(requesterId);
      await deleteNotif(notifId);
      await fetchTabCounts();
    } catch (err) {
      console.error(`Failed to ${decision} follow request`, err);
    } finally {
      setFollowActionLoading((prev) => {
        const next = { ...prev };
        delete next[notifId];
        return next;
      });
    }
  };

  const getPageNums = () => {
    const w     = Math.min(5, totalPages);
    let   start = Math.max(1, page - Math.floor(w / 2));
    let   end   = Math.min(totalPages, start + w - 1);
    start        = Math.max(1, end - w + 1);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  };

  const totalUnread = tabCounts?.all ?? tabCounts?.unread ?? 0;

  return (
    <div className="min-h-screen max-w-[1100px] mx-auto bg-white dark:bg-black">

      {/* ── Sticky header ──────────────────────────────────────────────────── */}
      <div className="sticky top-[56px] md:top-0 z-20 bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-100 dark:border-gray-900">
        <div className="flex items-center justify-between px-4 pt-4 pb-3">
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white tracking-tight">Notifications</h1>
            <WsIndicator status={wsStatus} />
          </div>
          <div className="flex items-center gap-2">
            {totalUnread > 0 && (
              <button
                onClick={handleMarkAll}
                disabled={markingAll}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300 text-xs font-semibold hover:bg-gray-200 dark:hover:bg-gray-800 disabled:opacity-60 transition-colors"
              >
                {markingAll
                  ? <Loader2 size={11} className="animate-spin" />
                  : <CheckCheck size={11} />}
                Mark all read
              </button>
            )}
            <button
              onClick={() => { refresh(); fetchTabCounts(); }}
              className="p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-900 transition-colors"
            >
              <RefreshCw size={16} className="text-gray-500 dark:text-gray-400" />
            </button>
          </div>
        </div>

        {/* Filter chips with per-tab badge counts */}
        <div className="flex gap-2 overflow-x-auto px-4 pb-3 scrollbar-hide">
          {FILTER_TABS.map((tab) => {
            const count = tabCounts[tab.key] ?? 0;
            const isActive = activeTab === tab.key;
            return (
              <button
                key={tab.key}
                onClick={() => handleTabChange(tab.key)}
                className={`relative flex-shrink-0 flex items-center gap-1 px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all whitespace-nowrap ${
                  isActive
                    ? "bg-gray-900 dark:bg-white text-white dark:text-black"
                    : "bg-gray-100 dark:bg-gray-900 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-800"
                }`}
              >
                {tab.emoji && <span>{tab.emoji}</span>}
                {tab.label}

                {/* Badge: show on every tab that has unread items */}
                {!tabCountsLoading && count > 0 && (
                  <span className={`inline-flex items-center justify-center min-w-[16px] h-4 px-1 rounded-full text-[9px] font-black ${
                    tab.key === "unread"
                      ? "bg-blue-500 text-white"
                      : isActive
                        ? "bg-white/30 text-white dark:bg-black/30 dark:text-black"
                        : "bg-gray-300 dark:bg-gray-700 text-gray-700 dark:text-gray-300"
                  }`}>
                    {count > 99 ? "99+" : count}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* ── Body ───────────────────────────────────────────────────────────── */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3">
          <Loader2 size={28} className="animate-spin text-gray-300 dark:text-gray-700" />
          <span className="text-sm text-gray-400">Loading…</span>
        </div>
      ) : error ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3 text-red-500">
          <AlertCircle size={28} />
          <span className="text-sm">{error}</span>
          <button onClick={() => { refresh(); fetchTabCounts(); }} className="text-xs underline text-blue-500">
            Retry
          </button>
        </div>
      ) : !hasGroups ? (
        <div className="flex flex-col items-center justify-center py-24 gap-4">
          <div className="w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-900 flex items-center justify-center">
            <Bell size={28} className="text-gray-300 dark:text-gray-700" />
          </div>
          <div className="text-center">
            <p className="text-base font-semibold text-gray-900 dark:text-white">No notifications</p>
            <p className="text-sm text-gray-400 mt-1">
              {activeTab !== "all" ? "No notifications in this category" : "You're all caught up!"}
            </p>
          </div>
          {activeTab !== "all" && (
            <button
              onClick={() => handleTabChange("all")}
              className="text-sm text-blue-500 font-semibold"
            >
              View all
            </button>
          )}
        </div>
      ) : (
        <div className="pb-24 md:pb-8">

          {groups.new.length > 0 && (
            <>
              <SectionLabel label="New" />
              {groups.new.map((n) => (
                <NotifRow
                  key={n._id}
                  notif={n}
                  onMarkRead={markRead}
                  onDelete={deleteNotif}
                  onFollowDecision={handleFollowDecision}
                  actionState={followActionLoading[n._id] || ""}
                />
              ))}
            </>
          )}

          {groups.week.length > 0 && (
            <>
              <SectionLabel label="This week" />
              {groups.week.map((n) => (
                <NotifRow
                  key={n._id}
                  notif={n}
                  onMarkRead={markRead}
                  onDelete={deleteNotif}
                  onFollowDecision={handleFollowDecision}
                  actionState={followActionLoading[n._id] || ""}
                />
              ))}
            </>
          )}

          {groups.earlier.length > 0 && (
            <>
              <SectionLabel label="Earlier" />
              {groups.earlier.map((n) => (
                <NotifRow
                  key={n._id}
                  notif={n}
                  onMarkRead={markRead}
                  onDelete={deleteNotif}
                  onFollowDecision={handleFollowDecision}
                  actionState={followActionLoading[n._id] || ""}
                />
              ))}
            </>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 px-4 py-6 border-t border-gray-100 dark:border-gray-900 mt-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
                className="p-2 rounded-full border border-gray-200 dark:border-gray-800 disabled:opacity-30 hover:bg-gray-50 dark:hover:bg-gray-900"
              >
                <ChevronLeft size={15} />
              </button>
              {getPageNums().map((p) => (
                <button
                  key={p}
                  onClick={() => setPage(p)}
                  className={`w-8 h-8 rounded-full text-xs font-bold transition-colors ${
                    page === p
                      ? "bg-gray-900 dark:bg-white text-white dark:text-black"
                      : "text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-900"
                  }`}
                >
                  {p}
                </button>
              ))}
              <button
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
                className="p-2 rounded-full border border-gray-200 dark:border-gray-800 disabled:opacity-30 hover:bg-gray-50 dark:hover:bg-gray-900"
              >
                <ChevronRight size={15} />
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
