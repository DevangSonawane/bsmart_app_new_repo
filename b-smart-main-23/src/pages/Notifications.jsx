/**
 * Notifications.jsx — Instagram-style notification feed
 */

import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bell, Heart, MessageCircle, UserPlus, AtSign,
  RefreshCw, CheckCheck, Trash2, AlertCircle,
  Loader2, ChevronLeft, ChevronRight, Bookmark, Star
} from "lucide-react";
import { useNotificationSocket } from "../hooks/useNotificationSocket";
import { acceptFollowRequest, declineFollowRequest } from "../services/followService";
import Avatar from '../components/Avatar';

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

const groupByTime = (notifications) => {
  const now = Date.now();
  const DAY = 86400000;
  const WEEK = 7 * DAY;

  const groups = { new: [], week: [], earlier: [] };
  notifications.forEach(n => {
    const age = now - new Date(n.createdAt).getTime();
    if (age < DAY)        groups.new.push(n);
    else if (age < WEEK)  groups.week.push(n);
    else                  groups.earlier.push(n);
  });
  return groups;
};

// ─── Type config ──────────────────────────────────────────────────────────────
const TYPE_CONFIG = {
  like:             { icon: Heart,         color: "text-pink-500",   bg: "bg-pink-500",    label: "Like"             },
  comment:          { icon: MessageCircle, color: "text-orange-500", bg: "bg-orange-500",  label: "Comment"          },
  follow:           { icon: UserPlus,      color: "text-blue-500",   bg: "bg-blue-500",    label: "Follow"           },
  follow_request:   { icon: UserPlus,      color: "text-blue-500",   bg: "bg-blue-500",    label: "Follow Request"   },
  follow_accepted:  { icon: UserPlus,      color: "text-green-500",  bg: "bg-green-500",   label: "Accepted"         },
  mention:          { icon: AtSign,        color: "text-purple-500", bg: "bg-purple-500",  label: "Mention"          },
  save:             { icon: Bookmark,      color: "text-teal-500",   bg: "bg-teal-500",    label: "Save"             },
  reward:           { icon: Star,          color: "text-yellow-500", bg: "bg-yellow-500",  label: "Reward"           },
};
const getType = (t) => TYPE_CONFIG[t] || { icon: Bell, color: "text-gray-400", bg: "bg-gray-400", label: "Notification" };

const FILTER_TABS = [
  { key: "all",     label: "All"       },
  { key: "unread",  label: "Unread"    },
  { key: "like",    label: "Likes"     },
  { key: "comment", label: "Comments"  },
  { key: "follow",  label: "Follows"   },
  { key: "mention", label: "Mentions"  },
];

const LIMIT = 20;

// ─── Single notification row ───────────────────────────────────────────────────
const NotifRow = ({ notif, onMarkRead, onDelete, onFollowDecision, actionState }) => {
  const navigate = useNavigate();
  const cfg = getType(notif.type);
  const Icon = cfg.icon;
  const sender = notif.sender?.full_name || notif.sender?.username || "Someone";
  const isFollowRequest = notif.type === "follow_request";
  const isActing = Boolean(actionState);

  const handleClick = async () => {
    if (!notif.isRead) await onMarkRead(notif._id);
    if (notif.link) navigate(notif.link);
  };

  return (
    <div
      onClick={handleClick}
      className={`group flex items-start gap-3 px-4 py-3 cursor-pointer transition-colors active:bg-gray-50 dark:active:bg-white/5 ${!notif.isRead ? "bg-blue-50/40 dark:bg-blue-950/10" : "hover:bg-gray-50 dark:hover:bg-white/[0.02]"}`}
    >
      {/* Avatar + type badge */}
      <div className="relative shrink-0 mt-0.5">
        <Avatar name={sender} url={notif.sender?.avatar_url} size="md" />
        <div className={`absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full ${cfg.bg} flex items-center justify-center ring-2 ring-white dark:ring-black`}>
          <Icon size={10} className="text-white" strokeWidth={2.5} />
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className={`text-sm leading-snug break-words ${!notif.isRead ? "text-gray-900 dark:text-white" : "text-gray-700 dark:text-gray-300"}`}>
          {notif.message}
          <span className="text-gray-400 dark:text-gray-500 text-xs font-normal ml-1.5">{timeAgo(notif.createdAt)}</span>
        </p>

        {/* Follow request actions */}
        {isFollowRequest && (
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

      {/* Right side: thumbnail OR actions */}
      <div className="flex items-center gap-1.5 shrink-0">
        {notif.thumbnail_url && !isFollowRequest && (
          <img
            src={notif.thumbnail_url}
            alt=""
            className="w-11 h-11 rounded object-cover border border-gray-100 dark:border-gray-800"
          />
        )}
        {/* Mark read + delete — visible on hover/press */}
        <div className="flex flex-col gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          {!notif.isRead && (
            <button
              onClick={e => { e.stopPropagation(); onMarkRead(notif._id); }}
              className="p-1 rounded-md hover:bg-blue-100 dark:hover:bg-blue-900/30 text-blue-400"
              title="Mark read"
            >
              <CheckCheck size={14} />
            </button>
          )}
          <button
            onClick={e => { e.stopPropagation(); onDelete(notif._id); }}
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

// ─── Section label ─────────────────────────────────────────────────────────────
const SectionLabel = ({ label }) => (
  <div className="px-4 pt-5 pb-1.5">
    <span className="text-[13px] font-bold text-gray-900 dark:text-white">{label}</span>
  </div>
);

// ─── Main page ────────────────────────────────────────────────────────────────
export default function Notifications() {
  const [activeTab, setActiveTab] = useState("all");
  const [page, setPage] = useState(1);
  const [markingAll, setMarkingAll] = useState(false);
  const [followActionLoading, setFollowActionLoading] = useState({});

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

  const handleFollowDecision = async (notif, decision) => {
    const notifId = notif?._id;
    const requesterId = notif?.sender?._id || notif?.sender?.id;
    if (!notifId || !requesterId) return;
    setFollowActionLoading(prev => ({ ...prev, [notifId]: decision }));
    try {
      if (decision === "accept") await acceptFollowRequest(requesterId);
      else await declineFollowRequest(requesterId);
      await deleteNotif(notifId);
    } catch (e) {
      console.error(`Failed to ${decision} follow request`, e);
    } finally {
      setFollowActionLoading(prev => { const n = { ...prev }; delete n[notifId]; return n; });
    }
  };

  const groups = groupByTime(notifications);
  const hasGroups = groups.new.length + groups.week.length + groups.earlier.length > 0;

  const getPageNums = () => {
    const w = Math.min(5, totalPages);
    let start = Math.max(1, page - Math.floor(w / 2));
    let end = Math.min(totalPages, start + w - 1);
    start = Math.max(1, end - w + 1);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  };

  return (
    <div className="min-h-screen max-w-[700px] mx-auto px-4 py-8 bg-white dark:bg-black">
      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div className="sticky top-[56px] md:top-0 z-20 bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-100 dark:border-gray-900">
        <div className="flex items-center justify-between px-4 pt-4 pb-3">
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white tracking-tight">Notifications</h1>
          <div className="flex items-center gap-2">
            {unreadCount > 0 && (
              <button
                onClick={handleMarkAll}
                disabled={markingAll}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300 text-xs font-semibold hover:bg-gray-200 dark:hover:bg-gray-800 disabled:opacity-60 transition-colors"
              >
                {markingAll ? <Loader2 size={11} className="animate-spin" /> : <CheckCheck size={11} />}
                Mark all read
              </button>
            )}
            <button
              onClick={refresh}
              className="p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-900 transition-colors"
            >
              <RefreshCw size={16} className="text-gray-500 dark:text-gray-400" />
            </button>
          </div>
        </div>

        {/* Filter chips */}
        {/* <div className="flex gap-2 overflow-x-auto px-4 pb-3 scrollbar-hide">
          {FILTER_TABS.map(tab => (
            <button
              key={tab.key}
              onClick={() => handleTabChange(tab.key)}
              className={`flex-shrink-0 px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all whitespace-nowrap ${
                activeTab === tab.key
                  ? "bg-gray-900 dark:bg-white text-white dark:text-black"
                  : "bg-gray-100 dark:bg-gray-900 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-800"
              }`}
            >
              {tab.label}
              {tab.key === "unread" && unreadCount > 0 && (
                <span className="ml-1.5 inline-flex items-center justify-center w-4 h-4 rounded-full bg-blue-500 text-white text-[9px] font-black">
                  {unreadCount > 9 ? "9+" : unreadCount}
                </span>
              )}
            </button>
          ))}
        </div> */}
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
          <button onClick={refresh} className="text-xs underline text-blue-500">Retry</button>
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
            <button onClick={() => handleTabChange("all")} className="text-sm text-blue-500 font-semibold">
              View all
            </button>
          )}
        </div>
      ) : (
        <div className="divide-y-0 pb-24 md:pb-8">
          {/* New */}
          {groups.new.length > 0 && (
            <>
              <SectionLabel label="New" />
              {groups.new.map(n => (
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

          {/* This week */}
          {groups.week.length > 0 && (
            <>
              <SectionLabel label="This week" />
              {groups.week.map(n => (
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

          {/* Earlier */}
          {groups.earlier.length > 0 && (
            <>
              <SectionLabel label="Earlier" />
              {groups.earlier.map(n => (
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
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                className="p-2 rounded-full border border-gray-200 dark:border-gray-800 disabled:opacity-30 hover:bg-gray-50 dark:hover:bg-gray-900"
              >
                <ChevronLeft size={15} />
              </button>
              {getPageNums().map(p => (
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
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
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
