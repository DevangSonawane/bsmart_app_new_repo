import { useParams, useNavigate } from "react-router-dom";
import { useState, useEffect, useCallback } from "react";
import api from "../../lib/api";
import {
  ArrowLeft, CheckCircle, BarChart2, Users, MessageCircle,
  ThumbsDown, Clock, Eye, MapPin, Globe, Tag,
  Film, Hash, Building2, Coins, Heart, AlertCircle,
  ChevronDown, ChevronUp, RefreshCw
} from "lucide-react";
import {
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend
} from "recharts";

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

const Card = ({ title, children, className = "", action }) => (
  <div className={`bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-6 shadow-sm ${className}`}>
    {title && (
      <div className="flex justify-between items-center mb-5">
        <h3 className="text-base font-bold text-gray-900 dark:text-white">{title}</h3>
        {action}
      </div>
    )}
    {children}
  </div>
);

const StatCard = ({ label, value, color = "blue", icon: Icon }) => {
  const IconComponent = Icon;
  const colors = {
    blue:   "bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400",
    purple: "bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400",
    pink:   "bg-pink-50 text-pink-600 dark:bg-pink-900/20 dark:text-pink-400",
    orange: "bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400",
    green:  "bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400",
    red:    "bg-red-50 text-red-600 dark:bg-red-900/20 dark:text-red-400",
  };
  return (
    <div className="p-4 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 hover:shadow-md transition-shadow">
      <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-3 ${colors[color]}`}>
        <IconComponent className="w-5 h-5" />
      </div>
      <div className="text-2xl font-bold text-gray-900 dark:text-white mb-0.5">{value}</div>
      <div className="text-xs font-medium text-gray-500 dark:text-gray-400">{label}</div>
    </div>
  );
};

const InfoRow = ({ icon: Icon, label, value, mono = false }) => {
  const IconComponent = Icon;
  return (
    <div className="flex items-start justify-between gap-4 py-3 border-b border-gray-100 dark:border-gray-800 last:border-0">
      <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide min-w-[130px] flex-shrink-0">
        <IconComponent className="w-3.5 h-3.5 flex-shrink-0" />
        {label}
      </div>
      <div className={`text-sm font-semibold text-gray-800 dark:text-gray-200 text-right break-all ${mono ? "font-mono text-xs" : ""}`}>
        {value ?? "—"}
      </div>
    </div>
  );
};

const TagList = ({ items, color = "blue" }) => {
  const colors = {
    blue:   "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-300",
    purple: "bg-purple-50 text-purple-700 dark:bg-purple-900/20 dark:text-purple-300",
    green:  "bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300",
  };
  if (!items || items.length === 0)
    return <span className="text-sm text-gray-400 italic">None</span>;
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item, i) => (
        <span key={i} className={`px-2.5 py-1 rounded-full text-xs font-semibold ${colors[color]}`}>
          {item}
        </span>
      ))}
    </div>
  );
};

// Avatar — shows image or initials
const Avatar = ({ name, url, size = "w-8 h-8", textSize = "text-xs" }) => {
  const initials = (name || "U")
    .split(" ")
    .map(w => w[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
  if (url) {
    return (
      <img
        src={url}
        alt={name}
        className={`${size} rounded-full object-cover flex-shrink-0`}
        onError={e => { e.target.style.display = "none"; }}
      />
    );
  }
  return (
    <div className={`${size} rounded-full bg-gradient-to-br from-purple-500 to-indigo-500 flex items-center justify-center text-white ${textSize} font-bold flex-shrink-0`}>
      {initials}
    </div>
  );
};

// ─── Comment Item with Replies ────────────────────────────────────────────────

const CommentItem = ({ comment }) => {
  const [showReplies, setShowReplies]     = useState(false);
  const [replies, setReplies]             = useState([]);
  const [loadingReplies, setLoadingReplies] = useState(false);
  const [repliesFetched, setRepliesFetched] = useState(false);

  const toggleReplies = useCallback(async () => {
    // Already fetched — just toggle visibility
    if (repliesFetched) {
      setShowReplies(v => !v);
      return;
    }
    setLoadingReplies(true);
    try {
      const res = await api.get(`/ads/comments/${comment._id}/replies`);
      const data = Array.isArray(res.data)
        ? res.data
        : res.data?.replies || res.data?.data || [];
      setReplies(data);
      setRepliesFetched(true);
      setShowReplies(true);
    } catch (err) {
      console.error("Failed to fetch replies", err);
    } finally {
      setLoadingReplies(false);
    }
  }, [comment._id, repliesFetched]);

  const replyCount = comment.replies_count || comment.repliesCount || 0;
  const user       = comment.user_id || comment.user || {};
  const userName   = user.full_name || user.username || "User";
  const timeAgo    = comment.createdAt
    ? new Date(comment.createdAt).toLocaleDateString("en-IN", { dateStyle: "medium" })
    : "";

  return (
    <div className="space-y-2">
      {/* Comment bubble */}
      <div className="flex gap-3 items-start p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
        <Avatar name={userName} url={user.avatar_url || ""} />
        <div className="flex-1 min-w-0">
          <div className="flex justify-between items-center gap-2 mb-1">
            <span className="text-sm font-bold text-gray-900 dark:text-white truncate">{userName}</span>
            <span className="text-[10px] text-gray-400 whitespace-nowrap flex-shrink-0">{timeAgo}</span>
          </div>
          <p className="text-xs text-gray-600 dark:text-gray-300 leading-relaxed">
            {comment.text || comment.content || comment.comment || ""}
          </p>

          {/* Reply toggle button */}
          {replyCount > 0 && (
            <button
              onClick={toggleReplies}
              disabled={loadingReplies}
              className="mt-2 inline-flex items-center gap-1.5 text-[11px] font-semibold text-blue-600 dark:text-blue-400 hover:text-blue-700 transition-colors"
            >
              {loadingReplies ? (
                <RefreshCw className="w-3 h-3 animate-spin" />
              ) : showReplies ? (
                <ChevronUp className="w-3 h-3" />
              ) : (
                <ChevronDown className="w-3 h-3" />
              )}
              {showReplies
                ? "Hide replies"
                : `${replyCount} ${replyCount === 1 ? "reply" : "replies"}`}
            </button>
          )}
        </div>
      </div>

      {/* Replies list */}
      {showReplies && replies.length > 0 && (
        <div className="ml-10 space-y-2">
          {replies.map((reply, idx) => {
            const rUser = reply.user_id || reply.user || {};
            const rName = rUser.full_name || rUser.username || "User";
            const rTime = reply.createdAt
              ? new Date(reply.createdAt).toLocaleDateString("en-IN", { dateStyle: "medium" })
              : "";
            return (
              <div
                key={reply._id || idx}
                className="flex gap-2 items-start p-2.5 rounded-xl bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-900/30"
              >
                <Avatar name={rName} url={rUser.avatar_url || ""} size="w-6 h-6" textSize="text-[10px]" />
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between items-center gap-2 mb-0.5">
                    <span className="text-xs font-bold text-gray-900 dark:text-white truncate">{rName}</span>
                    <span className="text-[10px] text-gray-400 whitespace-nowrap">{rTime}</span>
                  </div>
                  <p className="text-xs text-gray-600 dark:text-gray-300 leading-relaxed">
                    {reply.text || reply.content || reply.comment || ""}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ─── Main Component ───────────────────────────────────────────────────────────

export default function AdDetails() {
  const { adId }   = useParams();
  const navigate   = useNavigate();

  const [ad, setAd]         = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]   = useState("");

  const [comments, setComments]               = useState([]);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [commentsPage, setCommentsPage]       = useState(1);
  const [commentsTotal, setCommentsTotal]     = useState(0);
  const COMMENTS_PER_PAGE = 5;

  const [showAllLikes, setShowAllLikes]       = useState(false);

  const COLORS = ["#3b82f6", "#ec4899", "#8b5cf6", "#f59e0b", "#10b981", "#ef4444"];

  // Fetch Ad
  useEffect(() => {
    if (!adId) return;
    (async () => {
      setLoading(true);
      setError("");
      try {
        const res = await api.get(`/ads/${adId}`);
        setAd(res.data);
      } catch (err) {
        console.error(err);
        setError("Failed to load ad details. Please try again.");
      } finally {
        setLoading(false);
      }
    })();
  }, [adId]);

  // Fetch Comments (paginated)
  useEffect(() => {
    if (!adId) return;
    (async () => {
      setCommentsLoading(true);
      try {
        const res = await api.get(`/ads/${adId}/comments`, {
          params: { page: commentsPage, limit: COMMENTS_PER_PAGE },
        });
        const data  = Array.isArray(res.data)
          ? res.data
          : res.data?.comments || res.data?.data || [];
        const total = res.data?.total || res.data?.totalCount || data.length;
        setComments(data);
        setCommentsTotal(total);
      } catch (err) {
        console.error("Comments fetch failed", err);
        setComments([]);
      } finally {
        setCommentsLoading(false);
      }
    })();
  }, [adId, commentsPage]);

  // ── Loading ──────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-pink-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500 font-medium">Loading ad details...</p>
        </div>
      </div>
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────
  if (error || !ad) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black flex items-center justify-center p-6">
        <div className="text-center max-w-md">
          <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
          <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Failed to Load</h2>
          <p className="text-gray-500 mb-6">{error || "Ad not found."}</p>
          <button
            onClick={() => navigate("/vendor/ads-management")}
            className="px-6 py-2.5 bg-blue-600 text-white rounded-xl font-bold text-sm hover:bg-blue-700 transition-colors"
          >
            Back to Ads Management
          </button>
        </div>
      </div>
    );
  }

  // ── Derived values ───────────────────────────────────────────────────────
  const status         = ad.status || "draft";
  const media          = ad.media?.[0] || null;
  const thumbnail      = media?.thumbnails?.[0]?.fileUrl || null;
  const isVideo        = media?.media_type === "video";
  const totalBudget    = ad.total_budget_coins || 0;
  const coinsSpent     = ad.total_coins_spent  || 0;
  const coinsRemaining = totalBudget - coinsSpent;
  const spendPct       = totalBudget > 0 ? Math.round((coinsSpent / totalBudget) * 100) : 0;

  const likesList      = Array.isArray(ad.likes)    ? ad.likes    : [];
  const dislikesList   = Array.isArray(ad.dislikes) ? ad.dislikes : [];
  const visibleLikes   = showAllLikes ? likesList : likesList.slice(0, 8);

  const engagementData = [
    { name: "Likes",    value: ad.likes_count    || 0 },
    { name: "Dislikes", value: ad.dislikes_count || 0 },
    { name: "Comments", value: ad.comments_count || 0 },
  ].filter(d => d.value > 0);

  const totalCommentPages = Math.max(1, Math.ceil(commentsTotal / COMMENTS_PER_PAGE));

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-4 md:p-8">
        <div className="pb-20 pt-2">

          {/* ── Header ─────────────────────────────────────────────────── */}
          <div className="flex items-center gap-4 mb-8">
            <button
              onClick={() => navigate("/vendor/ads-management")}
              className="p-2.5 rounded-xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm flex-shrink-0"
            >
              <ArrowLeft className="w-5 h-5 text-gray-600 dark:text-gray-300" />
            </button>
            <div>
              <div className="flex items-center gap-3 flex-wrap">
                <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
                  {ad.caption || "Ad Details"}
                </h1>
                <Badge status={status} />
              </div>
              <div className="text-sm text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2 flex-wrap">
                <span className="font-mono bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded text-xs">
                  ID: {ad._id}
                </span>
                <span>•</span>
                <span>
                  {new Date(ad.createdAt).toLocaleDateString("en-IN", { dateStyle: "medium" })}
                </span>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

            {/* ══ LEFT COLUMN (2/3) ═══════════════════════════════════════ */}
            <div className="lg:col-span-2 space-y-8">

              {/* Media Preview */}
              {media && (
                <Card title="Media Preview">
                  <div className="flex flex-col sm:flex-row gap-6 items-start">
                    <div
                      className="relative w-36 flex-shrink-0 rounded-xl overflow-hidden bg-black"
                      style={{ aspectRatio: "9/16" }}
                    >
                      {thumbnail ? (
                        <img src={thumbnail} alt="thumbnail" className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-gray-500">
                          <Film className="w-8 h-8" />
                        </div>
                      )}
                      {isVideo && (
                        <div className="absolute inset-0 flex items-center justify-center">
                          <div className="w-10 h-10 rounded-full bg-white/80 flex items-center justify-center shadow">
                            <div className="w-0 h-0 border-t-[6px] border-t-transparent border-b-[6px] border-b-transparent border-l-[10px] border-l-gray-800 ml-1" />
                          </div>
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <InfoRow icon={Film}     label="Type"        value={media.media_type} />
                      <InfoRow icon={Film}     label="File"        value={media.fileName} mono />
                      {isVideo && media.video_meta && (
                        <>
                          <InfoRow icon={Clock} label="Duration"    value={`${media.video_meta.final_duration?.toFixed(2)}s`} />
                          <InfoRow icon={Clock} label="Original"    value={`${media.video_meta.original_length_seconds?.toFixed(2)}s`} />
                          <InfoRow icon={Clock} label="Trim Range"  value={`${media.video_meta.selected_start?.toFixed(2)}s – ${media.video_meta.selected_end?.toFixed(2)}s`} />
                        </>
                      )}
                      {media.crop_settings && (
                        <InfoRow icon={BarChart2} label="Aspect Ratio" value={media.crop_settings.aspect_ratio} />
                      )}
                      {media.image_editing?.filter?.name && (
                        <InfoRow icon={Tag} label="Filter" value={media.image_editing.filter.name} />
                      )}
                      <div className="pt-3">
                        <a
                          href={media.fileUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-blue-600 text-white text-xs font-bold hover:bg-blue-700 transition-colors"
                        >
                          <Eye className="w-3.5 h-3.5" /> Open Media
                        </a>
                      </div>
                    </div>
                  </div>
                </Card>
              )}

              {/* Stats Grid */}
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <StatCard label="Total Views"     value={(ad.views_count           || 0).toLocaleString()} icon={Eye}           color="blue"   />
                <StatCard label="Unique Views"    value={(ad.unique_views_count    || 0).toLocaleString()} icon={Users}         color="purple" />
                <StatCard label="Completed Views" value={(ad.completed_views_count || 0).toLocaleString()} icon={CheckCircle}   color="green"  />
                <StatCard label="Likes"           value={(ad.likes_count           || 0).toLocaleString()} icon={Heart}         color="pink"   />
                <StatCard label="Dislikes"        value={(ad.dislikes_count        || 0).toLocaleString()} icon={ThumbsDown}    color="red"    />
                <StatCard label="Comments"        value={(ad.comments_count        || 0).toLocaleString()} icon={MessageCircle} color="orange" />
              </div>

              {/* Ad Information */}
              <Card title="Ad Information">
                <InfoRow icon={Hash}        label="Caption"      value={ad.caption}      />
                <InfoRow icon={Tag}         label="Category"     value={ad.category}     />
                <InfoRow icon={Film}        label="Content Type" value={ad.content_type} />
                <InfoRow icon={MapPin}      label="Location"     value={ad.location}     />
                <InfoRow icon={AlertCircle} label="Status"       value={<Badge status={ad.status} />} />
                {ad.rejection_reason ? (
                  <InfoRow icon={AlertCircle} label="Reject Reason" value={ad.rejection_reason} />
                ) : null}
                <InfoRow icon={Clock} label="Created At" value={new Date(ad.createdAt).toLocaleString("en-IN")} />
                <InfoRow icon={Clock} label="Updated At" value={new Date(ad.updatedAt).toLocaleString("en-IN")} />
              </Card>

              {/* Targeting Settings */}
              <Card title="Targeting Settings">
                <div className="space-y-6">
                  {/* Target Languages */}
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                        <Globe className="w-3.5 h-3.5" /> Target Languages
                      </div>
                      <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">
                        {(ad.target_language || []).length}
                      </span>
                    </div>
                    <TagList items={ad.target_language} color="blue" />
                  </div>

                  {/* Target Locations */}
                  <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                        <MapPin className="w-3.5 h-3.5" /> Target Locations
                      </div>
                      <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">
                        {(ad.target_location || []).length}
                      </span>
                    </div>
                    <TagList items={ad.target_location} color="purple" />
                  </div>

                  {/* Target Preferences */}
                  {(ad.target_preferences || []).length > 0 && (
                    <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                      <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                        <Tag className="w-3.5 h-3.5" /> Preferences
                      </div>
                      <TagList items={ad.target_preferences} color="green" />
                    </div>
                  )}

                  {/* Hashtags */}
                  {(ad.hashtags || []).length > 0 && (
                    <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                      <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                        <Hash className="w-3.5 h-3.5" /> Hashtags
                      </div>
                      <TagList items={ad.hashtags} color="green" />
                    </div>
                  )}
                </div>
              </Card>

              {/* Engagement Controls */}
              <Card title="Engagement Controls">
                <div className="space-y-3">
                  {[
                    { label: "Hide Likes Count", value: ad.engagement_controls?.hide_likes_count },
                    { label: "Disable Comments",  value: ad.engagement_controls?.disable_comments  },
                  ].map((ctrl, i) => (
                    <div key={i} className="flex items-center justify-between p-3.5 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                      <span className="text-sm font-semibold text-gray-700 dark:text-gray-200">{ctrl.label}</span>
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold border ${ctrl.value
                        ? "bg-red-100 text-red-700 border-red-200 dark:bg-red-900/30 dark:text-red-400 dark:border-red-800"
                        : "bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800"}`}
                      >
                        {ctrl.value ? "Enabled" : "Disabled"}
                      </span>
                    </div>
                  ))}
                </div>
              </Card>

              {/* ── Likes & Dislikes Array ──────────────────────────────── */}
              <Card
                title={`Likes (${ad.likes_count || 0})`}
                action={
                  likesList.length > 8 && (
                    <button
                      onClick={() => setShowAllLikes(v => !v)}
                      className="text-xs font-semibold text-blue-600 dark:text-blue-400 hover:underline"
                    >
                      {showAllLikes ? "Show Less" : `View All ${likesList.length}`}
                    </button>
                  )
                }
              >
                {likesList.length === 0 ? (
                  <div className="text-center py-8 text-gray-400">
                    <Heart className="w-8 h-8 mx-auto mb-2 opacity-30" />
                    <p className="text-sm">No likes yet</p>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    {visibleLikes.map((like, i) => {
                      const u    = like.user_id || like.user || like;
                      const name = u.full_name || u.username || `User ${i + 1}`;
                      return (
                        <div
                          key={like._id || i}
                          className="flex items-center gap-3 p-2.5 rounded-xl bg-gray-50 dark:bg-gray-800/50 hover:bg-pink-50 dark:hover:bg-pink-900/10 transition-colors"
                        >
                          <Avatar name={name} url={u.avatar_url || ""} />
                          <div className="min-w-0 flex-1">
                            <div className="text-sm font-semibold text-gray-900 dark:text-white truncate">{name}</div>
                            {u.username && (
                              <div className="text-xs text-gray-400 truncate">@{u.username}</div>
                            )}
                          </div>
                          <Heart className="w-3.5 h-3.5 text-pink-500 flex-shrink-0" />
                        </div>
                      );
                    })}
                  </div>
                )}

                {/* Dislikes sub-section */}
                {dislikesList.length > 0 && (
                  <div className="mt-5 pt-5 border-t border-gray-100 dark:border-gray-800">
                    <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">
                      <ThumbsDown className="w-3.5 h-3.5 text-red-400" />
                      Dislikes ({ad.dislikes_count || dislikesList.length})
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                      {dislikesList.slice(0, 6).map((dislike, i) => {
                        const u    = dislike.user_id || dislike.user || dislike;
                        const name = u.full_name || u.username || `User ${i + 1}`;
                        return (
                          <div
                            key={dislike._id || i}
                            className="flex items-center gap-3 p-2.5 rounded-xl bg-gray-50 dark:bg-gray-800/50"
                          >
                            <Avatar name={name} url={u.avatar_url || ""} />
                            <div className="min-w-0 flex-1">
                              <div className="text-sm font-semibold text-gray-900 dark:text-white truncate">{name}</div>
                              {u.username && <div className="text-xs text-gray-400 truncate">@{u.username}</div>}
                            </div>
                            <ThumbsDown className="w-3.5 h-3.5 text-red-400 flex-shrink-0" />
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </Card>

              {/* ── Comments Section ────────────────────────────────────── */}
              <Card title={`Comments (${commentsTotal || ad.comments_count || 0})`}>
                {commentsLoading ? (
                  <div className="flex items-center justify-center py-10 gap-3 text-gray-400">
                    <RefreshCw className="w-5 h-5 animate-spin" />
                    <span className="text-sm">Loading comments...</span>
                  </div>
                ) : comments.length === 0 ? (
                  <div className="text-center py-10 text-gray-400">
                    <MessageCircle className="w-8 h-8 mx-auto mb-2 opacity-30" />
                    <p className="text-sm">No comments yet</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {comments.map(comment => (
                      <CommentItem key={comment._id} comment={comment} />
                    ))}
                  </div>
                )}

                {/* Pagination */}
                {totalCommentPages > 1 && (
                  <div className="flex items-center justify-between mt-5 pt-4 border-t border-gray-100 dark:border-gray-800">
                    <button
                      onClick={() => setCommentsPage(p => Math.max(1, p - 1))}
                      disabled={commentsPage === 1 || commentsLoading}
                      className="px-4 py-2 rounded-xl text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    >
                      ← Prev
                    </button>
                    <span className="text-xs text-gray-500">
                      Page {commentsPage} of {totalCommentPages}
                    </span>
                    <button
                      onClick={() => setCommentsPage(p => Math.min(totalCommentPages, p + 1))}
                      disabled={commentsPage === totalCommentPages || commentsLoading}
                      className="px-4 py-2 rounded-xl text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    >
                      Next →
                    </button>
                  </div>
                )}
              </Card>

            </div>

            {/* ══ RIGHT COLUMN (1/3) ══════════════════════════════════════ */}
            <div className="space-y-8">

              {/* Publisher Info */}
              <Card title="Publisher">
                <div className="flex items-center gap-3 mb-4">
                  <Avatar
                    name={ad.user_id?.full_name || "U"}
                    url={ad.user_id?.avatar_url || ""}
                    size="w-12 h-12"
                    textSize="text-sm"
                  />
                  <div>
                    <div className="font-bold text-sm text-gray-900 dark:text-white">
                      {ad.user_id?.full_name || "—"}
                    </div>
                    <div className="text-xs text-gray-500">@{ad.user_id?.username || "—"}</div>
                  </div>
                </div>
                <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                  <div className="flex items-center gap-2 text-xs text-gray-500 mb-1.5">
                    <Building2 className="w-3.5 h-3.5" />
                    <span className="font-bold uppercase tracking-wide">Business</span>
                  </div>
                  <div className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-2">
                    {ad.vendor_id?.business_name || "—"}
                  </div>
                  <span className={`inline-flex px-2.5 py-1 rounded-full text-[10px] font-bold border ${
                    ad.vendor_id?.validated
                      ? "bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800"
                      : "bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:border-gray-700"
                  }`}>
                    {ad.vendor_id?.validated ? "✓ Verified" : "Unverified"}
                  </span>
                </div>
              </Card>

              {/* Budget & Coins */}
              <Card title="Budget & Coins">
                <div className="relative p-5 rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white overflow-hidden mb-5 shadow-lg">
                  <div className="absolute top-0 right-0 w-28 h-28 bg-orange-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
                  <div className="relative z-10">
                    <div className="text-[10px] text-gray-400 font-bold uppercase tracking-wider mb-1">Total Budget</div>
                    <div className="text-3xl font-extrabold mb-4 tracking-tight flex items-center gap-2">
                      <Coins className="w-6 h-6 text-yellow-400" />
                      {totalBudget.toLocaleString()}
                    </div>
                    <div className="grid grid-cols-2 gap-4 pt-3 border-t border-white/10">
                      <div>
                        <div className="text-gray-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Spent</div>
                        <div className="font-bold text-base text-red-400">{coinsSpent.toLocaleString()}</div>
                      </div>
                      <div>
                        <div className="text-gray-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Remaining</div>
                        <div className="font-bold text-base text-emerald-400">{coinsRemaining.toLocaleString()}</div>
                      </div>
                    </div>
                  </div>
                </div>
                <div className="mb-4">
                  <div className="flex justify-between text-xs text-gray-500 mb-1.5">
                    <span>Budget Used</span>
                    <span className="font-bold">{spendPct}%</span>
                  </div>
                  <div className="w-full bg-gray-100 dark:bg-gray-800 rounded-full h-2">
                    <div
                      className="h-2 rounded-full bg-gradient-to-r from-orange-500 to-pink-500 transition-all"
                      style={{ width: `${spendPct}%` }}
                    />
                  </div>
                </div>
                <div className="pt-3 border-t border-gray-100 dark:border-gray-800">
                  <div className="flex justify-between text-sm text-gray-500 dark:text-gray-400">
                    <span>Coins Reward</span>
                    <span className="font-semibold text-gray-800 dark:text-white">{ad.coins_reward ?? 0}</span>
                  </div>
                </div>
              </Card>

              {/* Engagement Pie */}
              <Card title="Engagement Breakdown">
                {engagementData.length > 0 ? (
                  <div className="h-52 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={engagementData}
                          cx="50%" cy="50%"
                          innerRadius={50} outerRadius={70}
                          paddingAngle={5} dataKey="value"
                        >
                          {engagementData.map((_, index) => (
                            <Cell key={index} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip contentStyle={{ borderRadius: "8px" }} />
                        <Legend verticalAlign="bottom" height={36} iconType="circle" />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                ) : (
                  <div className="text-center py-8 text-gray-400">
                    <BarChart2 className="w-8 h-8 mx-auto mb-2 opacity-30" />
                    <p className="text-sm">No engagement data yet</p>
                  </div>
                )}
              </Card>

              {/* Views Breakdown */}
              <Card title="Views Breakdown">
                <div className="space-y-2">
                  {[
                    { label: "Total Views",     value: ad.views_count           || 0, color: "bg-blue-500"   },
                    { label: "Unique Views",    value: ad.unique_views_count    || 0, color: "bg-purple-500" },
                    { label: "Completed Views", value: ad.completed_views_count || 0, color: "bg-green-500"  },
                  ].map((item, i) => (
                    <div key={i} className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                      <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                        <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${item.color}`} />
                        {item.label}
                      </div>
                      <span className="font-bold text-sm text-gray-900 dark:text-white">
                        {item.value.toLocaleString()}
                      </span>
                    </div>
                  ))}
                </div>
              </Card>

            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
